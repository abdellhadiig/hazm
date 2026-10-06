import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';

class BlockerStatus {
  const BlockerStatus({
    this.accessibility = false,
    this.running = false,
    this.restricted = false,
    this.notifications = false,
    this.dndAccess = false,
    this.battery = false,
    this.autostart = false,
    this.sdk = 0,
  });

  factory BlockerStatus.fromMap(Map<Object?, Object?> map) => BlockerStatus(
        accessibility: map['accessibility'] == true,
        running: map['running'] == true,
        restricted: map['restricted'] == true,
        notifications: map['notifications'] == true,
        dndAccess: map['dndAccess'] == true,
        battery: map['battery'] == true,
        autostart: map['autostart'] == true,
        sdk: readInt(map['sdk']),
      );

  final bool accessibility;
  final bool running;
  final bool restricted;
  final bool notifications;
  final bool dndAccess;
  final bool battery;
  final bool autostart;
  final int sdk;

  bool sameAs(BlockerStatus other) =>
      accessibility == other.accessibility &&
      running == other.running &&
      restricted == other.restricted &&
      notifications == other.notifications &&
      dndAccess == other.dndAccess &&
      battery == other.battery &&
      autostart == other.autostart &&
      sdk == other.sdk;
}

class SessionSnapshot {
  const SessionSnapshot({
    required this.startedAt,
    required this.planned,
    required this.elapsed,
    required this.paused,
    required this.isPaused,
    required this.pauseRemaining,
    required this.pauseLength,
    required this.attempts,
    required this.dnd,
    this.unguarded = Duration.zero,
    this.taskId,
    this.intention,
  });

  factory SessionSnapshot.fromMap(Map<Object?, Object?> map) => SessionSnapshot(
        startedAt: DateTime.fromMillisecondsSinceEpoch(readInt(map['startedAt'])),
        planned: Duration(milliseconds: readInt(map['plannedMs'])),
        elapsed: Duration(milliseconds: readInt(map['elapsedMs'])),
        paused: Duration(milliseconds: readInt(map['pausedMs'])),
        isPaused: map['paused'] == true,
        pauseRemaining: Duration(milliseconds: readInt(map['pauseRemainingMs'])),
        pauseLength: Duration(milliseconds: readInt(map['pauseLengthMs'])),
        attempts: readInt(map['attempts']),
        unguarded: Duration(milliseconds: readInt(map['unguardedMs'])),
        dnd: map['dnd'] == true,
        taskId: readText(map['taskId']),
        intention: readText(map['intention']),
      );

  final DateTime startedAt;
  final Duration planned;
  final Duration elapsed;
  final Duration paused;
  final bool isPaused;
  final Duration pauseRemaining;
  final Duration pauseLength;
  final int attempts;
  final Duration unguarded;
  final bool dnd;
  final String? taskId;
  final String? intention;
}

class InstalledApp {
  const InstalledApp({required this.package, required this.label, required this.essential});

  final String package;
  final String label;
  final bool essential;
}

class BlockedApp {
  const BlockedApp(this.package, this.label);

  final String package;
  final String label;
}

abstract final class Blocker {
  static const _channel = MethodChannel('com.hazm.hazm_app/blocker');
  static VoidCallback? _onBlocked;
  static ValueChanged<BlockerStatus>? _onStatus;

  static bool get available => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void onBlocked(VoidCallback? callback) {
    _onBlocked = callback;
    _listen();
  }

  static void onStatus(ValueChanged<BlockerStatus>? callback) {
    _onStatus = callback;
    _listen();
  }

  static void _listen() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'blocked':
          _onBlocked?.call();
        case 'status':
          final arguments = call.arguments;
          if (arguments is Map) _onStatus?.call(BlockerStatus.fromMap(arguments));
      }
      return null;
    });
  }

  static Future<T?> _call<T>(String method, [Map<String, Object?>? arguments]) async {
    if (!available) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static SessionSnapshot? _snapshot(Map<Object?, Object?>? map) => map == null ? null : SessionSnapshot.fromMap(map);

  static Future<BlockerStatus> status() async {
    final map = await _call<Map<Object?, Object?>>('status');
    return map == null ? const BlockerStatus() : BlockerStatus.fromMap(map);
  }

  static Future<SessionSnapshot?> session() async => _snapshot(await _call<Map<Object?, Object?>>('session'));

  static Future<SessionSnapshot?> start({
    required int minutes,
    required int bonusThreshold,
    required bool dnd,
    String? taskId,
    String? intention,
  }) async =>
      _snapshot(
        await _call<Map<Object?, Object?>>('start', {
          'minutes': minutes,
          'bonusThreshold': bonusThreshold,
          'dnd': dnd,
          'taskId': taskId,
          'intention': intention,
        }),
      );

  static Future<SessionSnapshot?> pause(int seconds) async =>
      _snapshot(await _call<Map<Object?, Object?>>('pause', {'seconds': seconds}));

  static Future<SessionSnapshot?> resume() async => _snapshot(await _call<Map<Object?, Object?>>('resume'));

  static Future<SessionSnapshot?> extend(int minutes) async =>
      _snapshot(await _call<Map<Object?, Object?>>('extend', {'minutes': minutes}));

  static Future<void> breakSession() => _call<void>('breakSession');

  static Future<void> cancelSession() => _call<void>('cancelSession');

  static Future<List<SessionRecord>> takeResults() async {
    final list = await _call<List<Object?>>('takeResults');
    return [
      for (final item in list ?? const <Object?>[])
        if (item is Map) SessionRecord.fromMap(item)
    ];
  }

  static Future<BlockedApp?> takeBlocked() async {
    final map = await _call<Map<Object?, Object?>>('takeBlocked');
    final package = readText(map?['package']);
    if (package == null) return null;
    return BlockedApp(package, readText(map?['label']) ?? package);
  }

  static Future<List<InstalledApp>> apps() async {
    final list = await _call<List<Object?>>('apps');
    return [
      for (final item in list ?? const <Object?>[])
        if (item is Map && readText(item['package']) != null)
          InstalledApp(
            package: item['package'] as String,
            label: readText(item['label']) ?? item['package'] as String,
            essential: item['essential'] == true,
          ),
    ];
  }

  static Future<Map<String, String>> labels(List<String> packages) async {
    if (packages.isEmpty) return const {};
    final map = await _call<Map<Object?, Object?>>('labels', {'packages': packages});
    return {
      for (final entry in (map ?? const <Object?, Object?>{}).entries)
        if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
    };
  }

  static Future<Uint8List?> icon(String package, int size) =>
      _call<Uint8List>('icon', {'package': package, 'size': size});

  static Future<Set<String>> allowedApps() async {
    final list = await _call<List<Object?>>('allowedApps');
    return {
      for (final item in list ?? const <Object?>[])
        if (item is String) item
    };
  }

  static Future<void> setAllowedApps(Set<String> packages) =>
      _call<void>('setAllowedApps', {'packages': packages.toList()});

  static Future<void> setLanguage(String code) => _call<void>('setLanguage', {'code': code});

  static Future<bool> openAccessibilitySettings() async => await _call<bool>('openAccessibilitySettings') ?? false;

  static Future<bool> openAppDetails() async => await _call<bool>('openAppDetails') ?? false;

  static Future<bool> openNotificationSettings() async => await _call<bool>('openNotificationSettings') ?? false;

  static Future<bool> openDndSettings() async => await _call<bool>('openDndSettings') ?? false;

  static Future<bool> requestBatteryExemption() async => await _call<bool>('requestBatteryExemption') ?? false;

  static Future<bool> openAutostart() async => await _call<bool>('openAutostart') ?? false;

  static Future<bool> testGuard() async => await _call<bool>('testGuard') ?? false;

  static Future<String?> version() => _call<String>('version');

  static Future<bool> openUrl(String url) async => await _call<bool>('openUrl', {'url': url}) ?? false;
}
