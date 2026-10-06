int readInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String? readText(Object? value) => value is String && value.trim().isNotEmpty ? value : null;

Map<String, int> readCounts(Object? value) {
  if (value is! Map) return {};
  return {
    for (final entry in value.entries)
      if (entry.key is String && readInt(entry.value) > 0) entry.key as String: readInt(entry.value),
  };
}

String dayKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

enum SessionOutcome {
  completed,
  broken,
  interrupted;

  static SessionOutcome parse(Object? value) =>
      SessionOutcome.values.firstWhere((outcome) => outcome.name == value, orElse: () => SessionOutcome.interrupted);
}

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.focusedSeconds,
    required this.outcome,
    this.reason = '',
    this.bonus = false,
    this.capped = false,
    this.attempts = 0,
    this.unguardedSeconds = 0,
    this.apps = const {},
    this.taskId,
    this.intention,
  });

  factory SessionRecord.fromMap(Map<Object?, Object?> map) {
    final startedAt = DateTime.fromMillisecondsSinceEpoch(readInt(map['startedAt']));
    final focused = readInt(map['focusedSeconds']);
    return SessionRecord(
      id: readText(map['id']) ?? startedAt.millisecondsSinceEpoch.toString(),
      startedAt: startedAt,
      endedAt: DateTime.fromMillisecondsSinceEpoch(
        readInt(map['endedAt'], startedAt.millisecondsSinceEpoch + focused * 1000),
      ),
      plannedSeconds: readInt(map['plannedSeconds']),
      focusedSeconds: focused,
      outcome: SessionOutcome.parse(map['outcome']),
      reason: readText(map['reason']) ?? '',
      bonus: map['bonus'] == true,
      capped: map['capped'] == true,
      attempts: readInt(map['attempts']),
      unguardedSeconds: readInt(map['unguardedSeconds']),
      apps: readCounts(map['apps']),
      taskId: readText(map['taskId']),
      intention: readText(map['intention']),
    );
  }

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedSeconds;
  final int focusedSeconds;
  final SessionOutcome outcome;
  final String reason;
  final bool bonus;
  final bool capped;
  final int attempts;
  final int unguardedSeconds;
  final Map<String, int> apps;
  final String? taskId;
  final String? intention;

  bool get completed => outcome == SessionOutcome.completed;

  SessionRecord asCapped() => SessionRecord(
        id: id,
        startedAt: startedAt,
        endedAt: endedAt,
        plannedSeconds: plannedSeconds,
        focusedSeconds: focusedSeconds,
        outcome: outcome,
        reason: reason,
        capped: true,
        attempts: attempts,
        unguardedSeconds: unguardedSeconds,
        apps: apps,
        taskId: taskId,
        intention: intention,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt.millisecondsSinceEpoch,
        'plannedSeconds': plannedSeconds,
        'focusedSeconds': focusedSeconds,
        'outcome': outcome.name,
        'reason': reason,
        'bonus': bonus,
        'capped': capped,
        'attempts': attempts,
        'unguardedSeconds': unguardedSeconds,
        'apps': apps,
        'taskId': taskId,
        'intention': intention,
      };
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.done = false,
    this.doneAt,
    this.focusSeconds = 0,
  });

  factory TaskItem.fromMap(Map<Object?, Object?> map) {
    final created = DateTime.fromMillisecondsSinceEpoch(readInt(map['createdAt']));
    final doneAt = readInt(map['doneAt']);
    return TaskItem(
      id: readText(map['id']) ?? created.microsecondsSinceEpoch.toString(),
      title: readText(map['title']) ?? '',
      createdAt: created,
      done: map['done'] == true,
      doneAt: doneAt > 0 ? DateTime.fromMillisecondsSinceEpoch(doneAt) : null,
      focusSeconds: readInt(map['focusSeconds']),
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final bool done;
  final DateTime? doneAt;
  final int focusSeconds;

  TaskItem toggled(DateTime now) => TaskItem(
        id: id,
        title: title,
        createdAt: createdAt,
        done: !done,
        doneAt: done ? null : now,
        focusSeconds: focusSeconds,
      );

  TaskItem renamed(String value) => TaskItem(
        id: id,
        title: value,
        createdAt: createdAt,
        done: done,
        doneAt: doneAt,
        focusSeconds: focusSeconds,
      );

  TaskItem withFocus(int seconds) => TaskItem(
        id: id,
        title: title,
        createdAt: createdAt,
        done: done,
        doneAt: doneAt,
        focusSeconds: focusSeconds + seconds,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'done': done,
        'doneAt': doneAt?.millisecondsSinceEpoch,
        'focusSeconds': focusSeconds,
      };
}

class Preferences {
  const Preferences({
    this.language = 'en',
    this.onboarded = false,
    this.selectedMinutes = 45,
    this.dailyGoalMinutes = 120,
    this.bonusThresholdMinutes = 90,
    this.dailyUnlockLimit = 2,
    this.pushUpGoal = 30,
    this.pushUpSeconds = 30,
    this.dnd = false,
    this.haptics = true,
    this.updates = true,
  });

  factory Preferences.fromMap(Map<Object?, Object?> map) => Preferences(
        language: map['language'] == 'ar' ? 'ar' : 'en',
        onboarded: map['onboarded'] == true,
        selectedMinutes: readInt(map['selectedMinutes'], 45).clamp(5, 240),
        dailyGoalMinutes: readInt(map['dailyGoalMinutes'], 120).clamp(15, 600),
        bonusThresholdMinutes: readInt(map['bonusThresholdMinutes'], 90).clamp(30, 240),
        dailyUnlockLimit: readInt(map['dailyUnlockLimit'], 2).clamp(1, 5),
        pushUpGoal: readInt(map['pushUpGoal'], 30).clamp(5, 200),
        pushUpSeconds: readInt(map['pushUpSeconds'], 30).clamp(10, 120),
        dnd: map['dnd'] == true,
        haptics: map['haptics'] != false,
        updates: map['updates'] != false,
      );

  final String language;
  final bool onboarded;
  final int selectedMinutes;
  final int dailyGoalMinutes;
  final int bonusThresholdMinutes;
  final int dailyUnlockLimit;
  final int pushUpGoal;
  final int pushUpSeconds;
  final bool dnd;
  final bool haptics;
  final bool updates;

  Preferences copyWith({
    String? language,
    bool? onboarded,
    int? selectedMinutes,
    int? dailyGoalMinutes,
    int? bonusThresholdMinutes,
    int? dailyUnlockLimit,
    int? pushUpGoal,
    int? pushUpSeconds,
    bool? dnd,
    bool? haptics,
    bool? updates,
  }) =>
      Preferences(
        language: language ?? this.language,
        onboarded: onboarded ?? this.onboarded,
        selectedMinutes: selectedMinutes ?? this.selectedMinutes,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        bonusThresholdMinutes: bonusThresholdMinutes ?? this.bonusThresholdMinutes,
        dailyUnlockLimit: dailyUnlockLimit ?? this.dailyUnlockLimit,
        pushUpGoal: pushUpGoal ?? this.pushUpGoal,
        pushUpSeconds: pushUpSeconds ?? this.pushUpSeconds,
        dnd: dnd ?? this.dnd,
        haptics: haptics ?? this.haptics,
        updates: updates ?? this.updates,
      );

  Map<String, Object?> toJson() => {
        'language': language,
        'onboarded': onboarded,
        'selectedMinutes': selectedMinutes,
        'dailyGoalMinutes': dailyGoalMinutes,
        'bonusThresholdMinutes': bonusThresholdMinutes,
        'dailyUnlockLimit': dailyUnlockLimit,
        'pushUpGoal': pushUpGoal,
        'pushUpSeconds': pushUpSeconds,
        'dnd': dnd,
        'haptics': haptics,
        'updates': updates,
      };
}

class Wallet {
  const Wallet({this.earned = 2, this.used = 0, this.unlockDay = '', this.unlocksToday = 0});

  factory Wallet.fromMap(Map<Object?, Object?> map) => Wallet(
        earned: readInt(map['earned'], 2),
        used: readInt(map['used']),
        unlockDay: readText(map['unlockDay']) ?? '',
        unlocksToday: readInt(map['unlocksToday']),
      );

  final int earned;
  final int used;
  final String unlockDay;
  final int unlocksToday;

  static const cap = 10;

  int get available => (earned - used).clamp(0, 9999);

  bool get full => available >= cap;

  int unlocksOn(String day) => unlockDay == day ? unlocksToday : 0;

  Wallet earn() =>
      full ? this : Wallet(earned: earned + 1, used: used, unlockDay: unlockDay, unlocksToday: unlocksToday);

  Wallet spend(String day) => Wallet(
        earned: earned,
        used: used + 1,
        unlockDay: day,
        unlocksToday: unlocksOn(day) + 1,
      );

  Map<String, Object?> toJson() => {
        'earned': earned,
        'used': used,
        'unlockDay': unlockDay,
        'unlocksToday': unlocksToday,
      };
}

class PushUpLog {
  const PushUpLog({this.total = 0, this.byDay = const {}});

  factory PushUpLog.fromMap(Map<Object?, Object?> map) => PushUpLog(
        total: readInt(map['total']),
        byDay: readCounts(map['byDay']),
      );

  final int total;
  final Map<String, int> byDay;

  int on(String day) => byDay[day] ?? 0;

  PushUpLog add(String day, int count) {
    final days = Map<String, int>.of(byDay)..update(day, (value) => value + count, ifAbsent: () => count);
    final keys = days.keys.toList()..sort();
    while (keys.length > 120) {
      days.remove(keys.removeAt(0));
    }
    return PushUpLog(total: total + count, byDay: days);
  }

  Map<String, Object?> toJson() => {'total': total, 'byDay': byDay};
}

class Lifetime {
  const Lifetime({this.sessions = 0, this.focusSeconds = 0, this.attempts = 0, this.apps = const {}});

  factory Lifetime.fromMap(Map<Object?, Object?> map) => Lifetime(
        sessions: readInt(map['sessions']),
        focusSeconds: readInt(map['focusSeconds']),
        attempts: readInt(map['attempts']),
        apps: readCounts(map['apps']),
      );

  final int sessions;
  final int focusSeconds;
  final int attempts;
  final Map<String, int> apps;

  Lifetime record(SessionRecord record) {
    final merged = Map<String, int>.of(apps);
    record.apps.forEach((name, count) => merged.update(name, (value) => value + count, ifAbsent: () => count));
    return Lifetime(
      sessions: sessions + (record.completed ? 1 : 0),
      focusSeconds: focusSeconds + record.focusedSeconds,
      attempts: attempts + record.attempts,
      apps: merged,
    );
  }

  Map<String, Object?> toJson() => {
        'sessions': sessions,
        'focusSeconds': focusSeconds,
        'attempts': attempts,
        'apps': apps,
      };
}

class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.download});

  static ReleaseInfo? fromMap(Object? value) {
    if (value is! Map) return null;
    final version = readText(value['version']);
    final download = readText(value['download']);
    if (version == null || download == null) return null;
    return ReleaseInfo(version: version, download: download);
  }

  final String version;
  final String download;

  Map<String, Object?> toJson() => {'version': version, 'download': download};
}

class UpdateState {
  const UpdateState({this.checkedAt, this.release, this.skipped = ''});

  factory UpdateState.fromMap(Map<Object?, Object?> map) {
    final checked = readInt(map['checkedAt']);
    return UpdateState(
      checkedAt: checked > 0 ? DateTime.fromMillisecondsSinceEpoch(checked) : null,
      release: ReleaseInfo.fromMap(map['release']),
      skipped: readText(map['skipped']) ?? '',
    );
  }

  final DateTime? checkedAt;
  final ReleaseInfo? release;
  final String skipped;

  UpdateState checked(DateTime time, ReleaseInfo latest) =>
      UpdateState(checkedAt: time, release: latest, skipped: skipped);

  UpdateState skip(String version) => UpdateState(checkedAt: checkedAt, release: release, skipped: version);

  Map<String, Object?> toJson() => {
        'checkedAt': checkedAt?.millisecondsSinceEpoch,
        'release': release?.toJson(),
        'skipped': skipped,
      };
}

class HazmData {
  const HazmData({
    this.preferences = const Preferences(),
    this.sessions = const [],
    this.tasks = const [],
    this.wallet = const Wallet(),
    this.pushUps = const PushUpLog(),
    this.lifetime = const Lifetime(),
    this.updates = const UpdateState(),
  });

  final Preferences preferences;
  final List<SessionRecord> sessions;
  final List<TaskItem> tasks;
  final Wallet wallet;
  final PushUpLog pushUps;
  final Lifetime lifetime;
  final UpdateState updates;
}
