import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazm_app/app.dart';
import 'package:hazm_app/state/app_state.dart';
import 'package:hazm_app/state/guard_controller.dart';
import 'package:hazm_app/state/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const blockerChannel = MethodChannel('com.hazm.hazm_app/blocker');
const permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');

class FakeBlocker {
  Map<String, Object?>? session;
  final calls = <String>[];
  final results = <Map<String, Object?>>[];
  Set<String> allowed = {};
  Map<String, String>? blocked;
  String? version;
  final opened = <String>[];
  bool accessibility = true;
  bool running = true;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'status':
        return {
          'accessibility': accessibility,
          'running': running,
          'restricted': false,
          'notifications': true,
          'dndAccess': false,
          'battery': true,
          'autostart': false,
          'sdk': 34,
        };
      case 'session':
        return session;
      case 'start':
        final arguments = call.arguments as Map<Object?, Object?>;
        final minutes = arguments['minutes'] as int;
        session = {
          'startedAt': DateTime.now().millisecondsSinceEpoch,
          'plannedMs': minutes * 60000,
          'elapsedMs': 0,
          'pausedMs': 0,
          'paused': false,
          'pauseRemainingMs': 0,
          'pauseLengthMs': 0,
          'attempts': 0,
          'dnd': false,
          'intention': arguments['intention'],
          'taskId': arguments['taskId'],
        };
        return session;
      case 'extend':
        final current = session;
        if (current == null) return null;
        final minutes = (call.arguments as Map<Object?, Object?>)['minutes'] as int;
        session = {...current, 'plannedMs': (current['plannedMs'] as int) + minutes * 60000};
        return session;
      case 'breakSession':
        final now = DateTime.now().millisecondsSinceEpoch;
        results.add({
          'id': 'broken-$now',
          'startedAt': now - 60000,
          'endedAt': now,
          'plannedSeconds': 2700,
          'focusedSeconds': 60,
          'outcome': 'broken',
        });
        session = null;
        return null;
      case 'takeResults':
        final pending = List.of(results);
        results.clear();
        return pending;
      case 'apps':
        return [
          {'package': 'com.example.chat', 'label': 'Chat', 'essential': false},
          {'package': 'com.android.settings', 'label': 'Settings', 'essential': true},
        ];
      case 'allowedApps':
        return allowed.toList();
      case 'labels':
        final packages = (call.arguments as Map<Object?, Object?>)['packages'] as List<Object?>;
        return {for (final package in packages) package: 'App $package'};
      case 'openAccessibilitySettings':
        return true;
      case 'testGuard':
        return running;
      case 'version':
        return version;
      case 'openUrl':
        opened.add((call.arguments as Map<Object?, Object?>)['url'] as String);
        return true;
      case 'takeBlocked':
        final pending = blocked;
        blocked = null;
        return pending;
      default:
        return null;
    }
  }
}

class Harness {
  const Harness(this.app, this.session, this.guard, this.fake);

  final AppState app;
  final SessionController session;
  final GuardController guard;
  final FakeBlocker fake;
}

String preferences({String language = 'en', bool onboarded = true}) =>
    jsonEncode({'language': language, 'onboarded': onboarded});

Future<Harness> pumpHazm(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Size size = const Size(1080, 2340),
  FakeBlocker? blocker,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final fake = blocker ?? FakeBlocker();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(blockerChannel, fake.handle);
  messenger.setMockMethodCallHandler(permissionChannel, (call) async {
    if (call.method == 'checkPermissionStatus') return 1;
    if (call.method == 'requestPermissions') {
      return {for (final permission in call.arguments as List<Object?>) permission: 1};
    }
    return null;
  });
  final app = await AppState.load();
  final session = SessionController(app);
  final guard = GuardController()..attach();
  addTearDown(guard.dispose);
  await tester.pumpWidget(HazmApp(app: app, session: session, guard: guard));
  await tester.pump(const Duration(milliseconds: 800));
  return Harness(app, session, guard, fake);
}

Future<void> settle(WidgetTester tester, [int milliseconds = 900]) async {
  for (var elapsed = 0; elapsed < milliseconds; elapsed += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
