import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazm_app/data/models.dart';
import 'package:hazm_app/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates data saved by the previous version', () async {
    final today = DateTime.now().toIso8601String().split('T').first;
    SharedPreferences.setMockInitialValues({
      'totalSessions': 7,
      'totalFocusSeconds': 36000,
      'streak': 3,
      'totalCreditsEarned': 4,
      'totalCreditsUsed': 1,
      'todayDate': today,
      'todayUnlocksUsed': 1,
      'dailyUnlockLimit': 3,
      'bonusThresholdMinutes': 120,
      'totalPushUps': 42,
      'todayPushUps': 12,
      'monthlyPushUpGoal': 40,
      'pushUpSecondsReward': 45,
      'selectedSeconds': 3600,
      'languageCode': 'ar',
      'sessions': jsonEncode([
        {'date': '2026-10-02T10:30:00.000', 'durationSeconds': 1800, 'completed': true, 'bonusEarned': false},
        {'date': '2026-10-01T09:00:00.000', 'durationSeconds': 600, 'completed': false, 'bonusEarned': false},
      ]),
      'tasks': jsonEncode([
        {'text': 'Write chapter', 'done': false, 'created': '2026-09-30T08:00:00.000'},
        {'text': 'Email', 'done': true, 'created': '2026-09-29T08:00:00.000'},
      ]),
    });
    final store = await Store.open();
    final data = await store.load();
    final prefs = await SharedPreferences.getInstance();

    expect(data.preferences.language, 'ar');
    expect(data.preferences.onboarded, isTrue);
    expect(data.preferences.selectedMinutes, 60);
    expect(data.preferences.bonusThresholdMinutes, 120);
    expect(data.preferences.dailyUnlockLimit, 3);
    expect(data.preferences.pushUpGoal, 40);
    expect(data.preferences.pushUpSeconds, 45);

    expect(data.sessions, hasLength(2));
    expect(data.sessions.first.outcome, SessionOutcome.completed);
    expect(data.sessions.first.focusedSeconds, 1800);
    expect(data.sessions.first.startedAt, DateTime(2026, 10, 2, 10));
    expect(data.sessions.last.outcome, SessionOutcome.broken);

    expect(data.tasks.map((task) => task.title), ['Write chapter', 'Email']);
    expect(data.tasks.last.done, isTrue);

    expect(data.wallet.available, 3);
    expect(data.wallet.unlocksOn(today), 1);
    expect(data.pushUps.total, 42);
    expect(data.pushUps.on(today), 12);
    expect(data.lifetime.sessions, 7);
    expect(data.lifetime.focusSeconds, 36000);

    expect(prefs.containsKey('totalSessions'), isFalse);
    expect(prefs.containsKey('sessions'), isFalse);
  });

  test('fresh install starts with defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    final data = await store.load();
    expect(store.hasPreferences, isFalse);
    expect(data.preferences.onboarded, isFalse);
    expect(data.sessions, isEmpty);
    expect(data.wallet.available, 2);
  });

  test('round-trips sessions and tasks', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    await store.load();
    final record = SessionRecord(
      id: '1',
      startedAt: DateTime(2026, 10, 3, 9),
      endedAt: DateTime(2026, 10, 3, 10),
      plannedSeconds: 3600,
      focusedSeconds: 3300,
      outcome: SessionOutcome.completed,
      bonus: true,
      attempts: 4,
      apps: const {'com.example.chat': 4},
      taskId: 't1',
      intention: 'Report',
    );
    await store.saveSessions([record]);
    await store.saveTasks([TaskItem(id: 't1', title: 'Report', createdAt: DateTime(2026, 10, 1), focusSeconds: 3300)]);
    final data = await Store(await SharedPreferences.getInstance()).load();
    final loaded = data.sessions.single;
    expect(loaded.focusedSeconds, 3300);
    expect(loaded.bonus, isTrue);
    expect(loaded.apps, {'com.example.chat': 4});
    expect(loaded.intention, 'Report');
    expect(data.tasks.single.focusSeconds, 3300);
  });

  test('wallet spending resets per day', () {
    const wallet = Wallet(earned: 3);
    final spent = wallet.spend('2026-10-03').spend('2026-10-03');
    expect(spent.available, 1);
    expect(spent.unlocksOn('2026-10-03'), 2);
    expect(spent.unlocksOn('2026-10-04'), 0);
  });
}
