import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazm_app/data/updates.dart';
import 'package:hazm_app/ui/focus/big_clock.dart';

import 'helpers.dart';

Finder clock(String pattern) => find.bySemanticsLabel(RegExp(pattern));

Future<void> hold(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await settle(tester, 1000);
  await gesture.up();
  await settle(tester, 600);
}

void main() {
  testWidgets('first launch shows permissions, switches to Arabic and continues into the app', (tester) async {
    final hazm = await pumpHazm(tester);
    expect(find.text('PERMISSIONS'), findsOneWidget);
    expect(find.text('ACCESSIBILITY SERVICE'), findsOneWidget);
    expect(find.text('BACKGROUND RUNNING'), findsOneWidget);

    await tester.tap(find.text('TEST'));
    await settle(tester);
    expect(hazm.fake.calls, contains('testGuard'));

    await tester.tap(find.text('العربية'));
    await settle(tester);
    expect(find.text('الصلاحيات'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('متابعة'));
    await settle(tester, 1200);
    expect(find.text('وضع العمل العميق'), findsOneWidget);
    expect(find.text('بدء الجلسة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick durations and the picker set the session length', (tester) async {
    final hazm = await pumpHazm(tester, prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()});
    expect(find.text('DEEP WORK MODE'), findsOneWidget);
    expect(clock('45:00 MINUTES SELECTED'), findsOneWidget);

    await tester.tap(find.text('25'));
    await settle(tester);
    expect(hazm.app.preferences.selectedMinutes, 25);
    expect(clock('25:00 MINUTES SELECTED'), findsOneWidget);

    await tester.tap(find.byType(BigClock));
    await settle(tester);
    expect(find.text('SET DURATION'), findsOneWidget);

    await tester.tap(find.text('1.5h'));
    await settle(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(clock('01:30:00 DURATION SET'), findsOneWidget);
    expect(find.text('DURATION SET'), findsOneWidget);
    expect(hazm.app.preferences.selectedMinutes, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tasks can be added, edited, focused on and completed', (tester) async {
    final hazm = await pumpHazm(tester, prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()});
    await tester.tap(find.text('Tasks'));
    await settle(tester);
    expect(find.text('NO TASKS YET'), findsOneWidget);

    await tester.tap(find.byTooltip('Add task'));
    await settle(tester);
    expect(find.text('NEW TASK'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Write the report');
    await tester.tap(find.text('Add'));
    await settle(tester);
    expect(find.text('Write the report'), findsOneWidget);
    expect(hazm.app.tasks, hasLength(1));
    expect(find.text('1 OPEN · 0 DONE'), findsOneWidget);

    await tester.tap(find.text('Write the report'));
    await settle(tester);
    expect(find.text('EDIT TASK'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Write the final report');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(hazm.app.tasks.single.title, 'Write the final report');

    await tester.tap(find.byTooltip('Focus on this task'));
    await settle(tester);
    expect(find.text('DEEP WORK MODE'), findsOneWidget);
    expect(find.text('Write the final report'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Mark as done'));
    await settle(tester);
    expect(hazm.app.tasks.single.done, isTrue);
    expect(find.text('COMPLETED (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats show today, streak, patterns and recent sessions', (tester) async {
    final now = DateTime.now();
    final sessions = [
      for (var offset = 0; offset < 3; offset++)
        {
          'id': '$offset',
          'startedAt': DateTime(now.year, now.month, now.day - offset, 9).millisecondsSinceEpoch,
          'endedAt': DateTime(now.year, now.month, now.day - offset, 10).millisecondsSinceEpoch,
          'plannedSeconds': 3600,
          'focusedSeconds': 3600,
          'outcome': 'completed',
          'attempts': 2,
          'apps': {'com.example.chat': 2},
          'intention': 'Chapter $offset',
        },
    ];
    await pumpHazm(
      tester,
      prefs: {'hazm.schema': 2, 'hazm.preferences': preferences(), 'hazm.sessions': jsonEncode(sessions)},
    );
    await tester.tap(find.text('Stats'));
    await settle(tester, 1500);
    expect(find.text('PERFORMANCE'), findsOneWidget);
    expect(find.text('FOCUSED TODAY'), findsOneWidget);
    expect(find.text('BEST 3'), findsOneWidget);
    expect(find.text('1h'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('BEST HOUR'), 300);
    await settle(tester);
    expect(find.text('9 AM'), findsOneWidget);

    await tester.scrollUntilVisible(find.textContaining('Chapter 0'), 300);
    expect(find.textContaining('Chapter 0'), findsOneWidget);
  });

  testWidgets('the settings sheet shows blocking status and switches the language', (tester) async {
    await pumpHazm(tester, prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()});
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester, 1200);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('BLOCKING IS READY'), findsOneWidget);
    expect(find.text('CREDIT SYSTEM'), findsOneWidget);

    await tester.tap(find.text('العربية'));
    await settle(tester, 1200);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('نظام النقاط'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a quick tap on LOCK IN explains how to start', (tester) async {
    final hazm = await pumpHazm(tester, prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()});
    await tester.tap(find.text('LOCK IN'));
    await settle(tester, 600);
    expect(find.text('Press and hold LOCK IN to start'), findsOneWidget);
    expect(hazm.fake.calls, isNot(contains('start')));
    expect(hazm.session.active, isFalse);
    await settle(tester, 3200);
    expect(find.text('Press and hold LOCK IN to start'), findsNothing);
  });

  testWidgets('holding LOCK IN starts a session that can be extended', (tester) async {
    final hazm = await pumpHazm(tester, prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()});
    await hold(tester, find.text('LOCK IN'));
    expect(hazm.fake.calls, contains('start'));
    expect(hazm.session.active, isTrue);
    expect(find.text('SESSION ACTIVE'), findsOneWidget);
    expect(find.text('TIME REMAINING'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('EARN A BREAK'), findsOneWidget);

    await tester.tap(find.text('+5 MIN'));
    await settle(tester);
    expect(hazm.fake.calls, contains('extend'));
    expect(hazm.session.planned, const Duration(minutes: 50));

    await tester.tap(find.text('Stats'));
    await settle(tester);
    expect(find.text('ACTIVE'), findsOneWidget);
    await tester.tap(find.text('Focus'));
    await settle(tester);

    hazm.fake.session = null;
    await hazm.session.refresh();
    await settle(tester, 4000);
    expect(find.text('LOCK IN'), findsOneWidget);
  });

  testWidgets('tapping LOCKED offers options and only a full hold spends a credit', (tester) async {
    final hazm = await pumpHazm(tester, prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()});
    await hazm.session.start(minutes: 45, intention: 'Write the report');
    await settle(tester);
    await tester.tap(find.text('LOCKED'));
    await settle(tester, 1200);
    expect(find.text('UNLOCK OPTIONS'), findsOneWidget);
    expect(find.text('EMERGENCY UNLOCK'), findsOneWidget);
    expect(find.text('PUSH-UPS'), findsOneWidget);
    expect(find.text('Write the report'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('HOLD TO UNLOCK'));
    await settle(tester, 600);
    expect(find.text('KEEP HOLDING'), findsOneWidget);
    expect(hazm.fake.calls, isNot(contains('breakSession')));
    expect(hazm.session.active, isTrue);

    final press = await tester.startGesture(tester.getCenter(find.text('KEEP HOLDING')));
    await settle(tester, 2000);
    await press.up();
    await settle(tester, 1200);
    expect(hazm.fake.calls, contains('breakSession'));
    expect(hazm.session.active, isFalse);
    expect(hazm.app.wallet.available, 1);
    expect(find.textContaining('Session ended'), findsOneWidget);
    await settle(tester, 4000);
  });

  testWidgets('opening a blocked app from the lock screen shows the unlock options', (tester) async {
    final hazm = await pumpHazm(tester, prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()});
    await hazm.session.start(minutes: 45);
    await settle(tester);
    await tester.tap(find.text('Stats'));
    await settle(tester);

    hazm.fake.blocked = {'package': 'com.example.chat', 'label': 'Chat'};
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester, 1500);
    expect(find.text('UNLOCK OPTIONS'), findsOneWidget);
    expect(find.text('CHAT IS BLOCKED'), findsOneWidget);
    expect(find.text('SESSION ACTIVE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('KEEP FOCUSING'));
    await settle(tester);
    expect(find.text('UNLOCK OPTIONS'), findsNothing);
    expect(hazm.session.active, isTrue);

    hazm.fake.session = null;
    await hazm.session.refresh();
    await settle(tester, 1200);
  });

  testWidgets('starting without the guard asks to turn it on, then starts by itself', (tester) async {
    final blocker = FakeBlocker()
      ..accessibility = false
      ..running = false;
    final hazm = await pumpHazm(
      tester,
      prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()},
      blocker: blocker,
    );
    await hold(tester, find.text('LOCK IN'));
    expect(find.text('TURN ON BLOCKING'), findsOneWidget);
    expect(hazm.session.active, isFalse);

    await tester.tap(find.text('TURN ON'));
    await settle(tester);
    expect(blocker.calls, contains('openAccessibilitySettings'));

    blocker
      ..accessibility = true
      ..running = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester, 2000);
    expect(find.text('TURN ON BLOCKING'), findsNothing);
    expect(hazm.session.active, isTrue);
    expect(find.text('SESSION ACTIVE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    blocker.session = null;
    await hazm.session.refresh();
    await settle(tester, 1200);
  });

  testWidgets('a stopped guard during a session shows a fix strip instead of ending it', (tester) async {
    final hazm = await pumpHazm(tester, prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()});
    await hazm.session.start(minutes: 45);
    await settle(tester);

    hazm.fake.running = false;
    await hazm.guard.refresh();
    await settle(tester, 3600);
    expect(hazm.session.active, isTrue);
    expect(find.text('BLOCKING IS OFF'), findsOneWidget);

    hazm.fake.running = true;
    await hazm.guard.refresh();
    await settle(tester);
    expect(find.text('BLOCKING IS OFF'), findsNothing);

    hazm.fake.session = null;
    await hazm.session.refresh();
    await settle(tester, 1200);
  });

  testWidgets('small screens lay out without overflow in Arabic', (tester) async {
    final hazm = await pumpHazm(
      tester,
      prefs: {'hazm.schema': 2, 'hazm.preferences': preferences(language: 'ar')},
      size: const Size(1080, 1920),
    );
    expect(tester.takeException(), isNull);
    for (final tab in ['الإحصائيات', 'المهام', 'التركيز']) {
      await tester.tap(find.text(tab));
      await settle(tester);
      expect(tester.takeException(), isNull);
    }

    await hazm.session.start(minutes: 90, intention: 'كتابة التقرير');
    await settle(tester);
    expect(find.text('الجلسة جارية'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('الإعدادات'));
    await settle(tester, 1200);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(tester.takeException(), isNull);

    hazm.fake.session = null;
    await hazm.session.refresh();
    await settle(tester, 1200);
  });

  testWidgets('a newer release shows an update that opens the download and can be skipped', (tester) async {
    const apk = 'https://github.com/abdellhadiig/hazm/releases/download/v1.0.2/HAZM.apk';
    final original = Updates.fetch;
    addTearDown(() => Updates.fetch = original);
    Updates.fetch = (uri) async => jsonEncode({
          'tag_name': 'v1.0.2',
          'assets': [
            {'name': 'HAZM.apk', 'browser_download_url': apk},
          ],
        });
    final blocker = FakeBlocker()..version = '1.0.1';
    await pumpHazm(tester, prefs: {'hazm.schema': 2, 'hazm.preferences': preferences()}, blocker: blocker);
    await settle(tester);

    expect(find.text('NEW VERSION 1.0.2'), findsOneWidget);
    await tester.tap(find.text('NEW VERSION 1.0.2'));
    await settle(tester, 300);
    expect(blocker.opened, [apk]);

    await tester.tap(find.byTooltip('Skip this version'));
    await settle(tester);
    expect(find.text('NEW VERSION 1.0.2'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
