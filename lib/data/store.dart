import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class Store {
  Store(this._prefs);

  final SharedPreferences _prefs;

  static const maxSessions = 600;
  static const _schemaVersion = 2;
  static const _schema = 'hazm.schema';
  static const _preferences = 'hazm.preferences';
  static const _sessions = 'hazm.sessions';
  static const _tasks = 'hazm.tasks';
  static const _wallet = 'hazm.wallet';
  static const _pushUps = 'hazm.pushups';
  static const _lifetime = 'hazm.lifetime';
  static const _updates = 'hazm.updates';
  static const _keys = [_preferences, _sessions, _tasks, _wallet, _pushUps, _lifetime, _updates];

  static const _legacyKeys = [
    'totalSessions',
    'totalFocusSeconds',
    'streak',
    'totalCreditsEarned',
    'totalCreditsUsed',
    'todayDate',
    'todayUnlocksUsed',
    'dailyUnlockLimit',
    'bonusThresholdMinutes',
    'lastSessionDay',
    'totalPushUps',
    'todayPushUps',
    'monthlyPushUpGoal',
    'pushUpSecondsReward',
    'selectedSeconds',
    'languageCode',
    'sessions',
    'tasks',
  ];

  static Future<Store> open() async => Store(await SharedPreferences.getInstance());

  bool get hasPreferences => _prefs.containsKey(_preferences);

  Future<HazmData> load() async {
    if (_prefs.getInt(_schema) != _schemaVersion) await _migrate();
    return HazmData(
      preferences: Preferences.fromMap(_object(_preferences)),
      sessions: _list(_sessions).map(SessionRecord.fromMap).toList(),
      tasks: _list(_tasks).map(TaskItem.fromMap).where((task) => task.title.isNotEmpty).toList(),
      wallet: Wallet.fromMap(_object(_wallet)),
      pushUps: PushUpLog.fromMap(_object(_pushUps)),
      lifetime: Lifetime.fromMap(_object(_lifetime)),
      updates: UpdateState.fromMap(_object(_updates)),
    );
  }

  Future<void> savePreferences(Preferences value) => _write(_preferences, value.toJson());

  Future<void> saveSessions(List<SessionRecord> value) =>
      _write(_sessions, value.take(maxSessions).map((session) => session.toJson()).toList());

  Future<void> saveTasks(List<TaskItem> value) => _write(_tasks, value.map((task) => task.toJson()).toList());

  Future<void> saveWallet(Wallet value) => _write(_wallet, value.toJson());

  Future<void> savePushUps(PushUpLog value) => _write(_pushUps, value.toJson());

  Future<void> saveLifetime(Lifetime value) => _write(_lifetime, value.toJson());

  Future<void> saveUpdates(UpdateState value) => _write(_updates, value.toJson());

  Future<void> clear({required Preferences keep}) async {
    for (final key in _keys) {
      await _prefs.remove(key);
    }
    await savePreferences(keep);
  }

  Future<void> _write(String key, Object value) => _prefs.setString(key, jsonEncode(value));

  Object? _decode(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Map<Object?, Object?> _object(String key) {
    final value = _decode(key);
    return value is Map ? value : const {};
  }

  List<Map<Object?, Object?>> _list(String key) {
    final value = _decode(key);
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) item
    ];
  }

  Future<void> _migrate() async {
    final p = _prefs;
    if (_legacyKeys.any(p.containsKey) && !p.containsKey(_preferences)) {
      final sessions = <SessionRecord>[];
      for (final item in _list('sessions')) {
        final ended = DateTime.tryParse(readText(item['date']) ?? '');
        if (ended == null) continue;
        final seconds = readInt(item['durationSeconds']);
        final completed = item['completed'] == true;
        sessions.add(
          SessionRecord(
            id: ended.millisecondsSinceEpoch.toString(),
            startedAt: ended.subtract(Duration(seconds: seconds)),
            endedAt: ended,
            plannedSeconds: seconds,
            focusedSeconds: seconds,
            outcome: completed ? SessionOutcome.completed : SessionOutcome.broken,
            reason: completed ? 'timeout' : 'unlock',
            bonus: item['bonusEarned'] == true,
          ),
        );
      }
      final tasks = <TaskItem>[];
      for (final item in _list('tasks')) {
        final title = readText(item['text']);
        if (title == null) continue;
        final created = DateTime.tryParse(readText(item['created']) ?? '') ?? DateTime.now();
        final done = item['done'] == true;
        tasks.add(
          TaskItem(
            id: '${created.microsecondsSinceEpoch}${tasks.length}',
            title: title,
            createdAt: created,
            done: done,
            doneAt: done ? created : null,
          ),
        );
      }
      final today = readText(p.getString('todayDate')) ?? '';
      await savePreferences(
        Preferences(
          language: p.getString('languageCode') == 'ar' ? 'ar' : 'en',
          onboarded: true,
          selectedMinutes: ((p.getInt('selectedSeconds') ?? 2700) / 60).round().clamp(5, 240),
          bonusThresholdMinutes: (p.getInt('bonusThresholdMinutes') ?? 90).clamp(30, 240),
          dailyUnlockLimit: (p.getInt('dailyUnlockLimit') ?? 2).clamp(1, 5),
          pushUpGoal: (p.getInt('monthlyPushUpGoal') ?? 30).clamp(5, 200),
          pushUpSeconds: (p.getInt('pushUpSecondsReward') ?? 30).clamp(10, 120),
        ),
      );
      await saveSessions(sessions);
      await saveTasks(tasks);
      await saveWallet(
        Wallet(
          earned: p.getInt('totalCreditsEarned') ?? 2,
          used: p.getInt('totalCreditsUsed') ?? 0,
          unlockDay: today,
          unlocksToday: p.getInt('todayUnlocksUsed') ?? 0,
        ),
      );
      final todayPushUps = p.getInt('todayPushUps') ?? 0;
      await savePushUps(
        PushUpLog(
          total: p.getInt('totalPushUps') ?? 0,
          byDay: today.isNotEmpty && todayPushUps > 0 ? {today: todayPushUps} : const {},
        ),
      );
      await saveLifetime(
        Lifetime(
          sessions: p.getInt('totalSessions') ?? sessions.where((s) => s.completed).length,
          focusSeconds: p.getInt('totalFocusSeconds') ?? 0,
        ),
      );
    }
    for (final key in _legacyKeys) {
      await p.remove(key);
    }
    await p.setInt(_schema, _schemaVersion);
  }
}
