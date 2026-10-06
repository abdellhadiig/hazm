import 'package:flutter/foundation.dart';

import '../core/haptics.dart';
import '../data/insights.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/updates.dart';
import '../platform/blocker.dart';

class AppState extends ChangeNotifier {
  AppState(this._store, HazmData data)
      : preferences = data.preferences,
        sessions = List.of(data.sessions),
        tasks = List.of(data.tasks),
        wallet = data.wallet,
        pushUps = data.pushUps,
        lifetime = data.lifetime,
        updates = data.updates,
        language = ValueNotifier(data.preferences.language) {
    Haptics.enabled = preferences.haptics;
  }

  static Future<AppState> load() async {
    final store = await Store.open();
    var data = await store.load();
    if (!store.hasPreferences) {
      final device = PlatformDispatcher.instance.locale.languageCode == 'ar' ? 'ar' : 'en';
      final preferences = data.preferences.copyWith(language: device);
      await store.savePreferences(preferences);
      data = HazmData(
        preferences: preferences,
        sessions: data.sessions,
        tasks: data.tasks,
        wallet: data.wallet,
        pushUps: data.pushUps,
        lifetime: data.lifetime,
        updates: data.updates,
      );
    }
    final state = AppState(store, data);
    await Blocker.setLanguage(state.preferences.language);
    return state;
  }

  final Store _store;
  final ValueNotifier<String> language;
  Preferences preferences;
  List<SessionRecord> sessions;
  List<TaskItem> tasks;
  Wallet wallet;
  PushUpLog pushUps;
  Lifetime lifetime;
  UpdateState updates;
  String? version;
  Insights? _insights;
  bool _checking = false;

  String get today => dayKey(DateTime.now());

  Insights get insights {
    final now = DateTime.now();
    final cached = _insights;
    if (cached != null && dayKey(cached.now) == dayKey(now)) return cached;
    return _insights = Insights(sessions, now);
  }

  int get unlocksLeftToday => (preferences.dailyUnlockLimit - wallet.unlocksOn(today)).clamp(0, 5);

  bool get canUnlock => wallet.available > 0 && unlocksLeftToday > 0;

  ReleaseInfo? get update {
    final release = updates.release;
    final current = version;
    if (!preferences.updates || release == null || current == null) return null;
    if (release.version == updates.skipped || !Updates.newer(release.version, current)) return null;
    return release;
  }

  int get pushUpsToday => pushUps.on(today);

  int get requiredPushUps => (300 / preferences.pushUpSeconds).ceil().clamp(1, 60);

  List<TaskItem> get openTasks => tasks.where((task) => !task.done).toList();

  List<TaskItem> get doneTasks => tasks.where((task) => task.done).toList()
    ..sort((a, b) => (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));

  TaskItem? taskById(String? id) {
    if (id == null) return null;
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  void updatePreferences(Preferences next) {
    final languageChanged = next.language != preferences.language;
    preferences = next;
    Haptics.enabled = next.haptics;
    _store.savePreferences(next);
    if (languageChanged) {
      language.value = next.language;
      Blocker.setLanguage(next.language);
    }
    notifyListeners();
  }

  SessionRecord record(SessionRecord result) {
    if (sessions.any((session) => session.id == result.id)) return result;
    final record = result.bonus && wallet.full ? result.asCapped() : result;
    sessions.insert(0, record);
    if (sessions.length > Store.maxSessions) sessions.removeRange(Store.maxSessions, sessions.length);
    lifetime = lifetime.record(record);
    if (record.bonus) wallet = wallet.earn();
    final taskId = record.taskId;
    if (taskId != null && record.focusedSeconds > 0) {
      tasks = [for (final task in tasks) task.id == taskId ? task.withFocus(record.focusedSeconds) : task];
      _store.saveTasks(tasks);
    }
    _insights = null;
    _store
      ..saveSessions(sessions)
      ..saveLifetime(lifetime)
      ..saveWallet(wallet);
    notifyListeners();
    return record;
  }

  Future<void> checkForUpdates() async {
    if (_checking || !preferences.updates) return;
    _checking = true;
    try {
      version ??= await Blocker.version();
      final last = updates.checkedAt;
      final now = DateTime.now();
      if (version == null || (last != null && now.difference(last) < Updates.interval)) return;
      final release = await Updates.latest();
      if (release == null) return;
      updates = updates.checked(now, release);
      _store.saveUpdates(updates);
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  void skipUpdate() {
    final release = updates.release;
    if (release == null) return;
    updates = updates.skip(release.version);
    _store.saveUpdates(updates);
    notifyListeners();
  }

  void spendUnlock() {
    wallet = wallet.spend(today);
    _store.saveWallet(wallet);
    notifyListeners();
  }

  void addPushUps(int count) {
    if (count <= 0) return;
    pushUps = pushUps.add(today, count);
    _store.savePushUps(pushUps);
    notifyListeners();
  }

  TaskItem addTask(String title) {
    final now = DateTime.now();
    final task = TaskItem(id: '${now.microsecondsSinceEpoch}', title: title.trim(), createdAt: now);
    tasks = [task, ...tasks];
    _saveTasks();
    return task;
  }

  void toggleTask(String id) {
    final now = DateTime.now();
    tasks = [for (final task in tasks) task.id == id ? task.toggled(now) : task];
    _saveTasks();
  }

  void renameTask(String id, String title) {
    final value = title.trim();
    if (value.isEmpty) return;
    tasks = [for (final task in tasks) task.id == id ? task.renamed(value) : task];
    _saveTasks();
  }

  (TaskItem, int)? removeTask(String id) {
    final index = tasks.indexWhere((task) => task.id == id);
    if (index < 0) return null;
    final removed = tasks[index];
    tasks = List.of(tasks)..removeAt(index);
    _saveTasks();
    return (removed, index);
  }

  void restoreTask(TaskItem task, int index) {
    if (tasks.any((item) => item.id == task.id)) return;
    tasks = List.of(tasks)..insert(index.clamp(0, tasks.length), task);
    _saveTasks();
  }

  void clearDoneTasks() {
    tasks = tasks.where((task) => !task.done).toList();
    _saveTasks();
  }

  void _saveTasks() {
    _store.saveTasks(tasks);
    notifyListeners();
  }

  Future<void> resetAll() async {
    final keep = const Preferences().copyWith(language: preferences.language, onboarded: true);
    await _store.clear(keep: keep);
    preferences = keep;
    sessions = [];
    tasks = [];
    wallet = const Wallet();
    pushUps = const PushUpLog();
    lifetime = const Lifetime();
    updates = const UpdateState();
    _insights = null;
    Haptics.enabled = keep.haptics;
    notifyListeners();
  }

  @override
  void dispose() {
    language.dispose();
    super.dispose();
  }
}
