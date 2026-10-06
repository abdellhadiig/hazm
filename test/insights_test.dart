import 'package:flutter_test/flutter_test.dart';
import 'package:hazm_app/data/insights.dart';
import 'package:hazm_app/data/models.dart';

SessionRecord session(
  DateTime start, {
  int minutes = 30,
  SessionOutcome outcome = SessionOutcome.completed,
  Map<String, int> apps = const {},
}) {
  return SessionRecord(
    id: '${start.millisecondsSinceEpoch}',
    startedAt: start,
    endedAt: start.add(Duration(minutes: minutes)),
    plannedSeconds: minutes * 60,
    focusedSeconds: minutes * 60,
    outcome: outcome,
    attempts: apps.values.fold(0, (sum, value) => sum + value),
    apps: apps,
  );
}

void main() {
  final now = DateTime(2026, 10, 3, 15);
  DateTime day(int offset, [int hour = 10]) => DateTime(now.year, now.month, now.day - offset, hour);

  test('current streak counts consecutive completed days ending today', () {
    final insights = Insights([session(day(0)), session(day(1)), session(day(2)), session(day(4))], now);
    expect(insights.currentStreak, 3);
    expect(insights.bestStreak, 3);
  });

  test('streak survives until the end of today when yesterday was completed', () {
    final insights = Insights([session(day(1)), session(day(2))], now);
    expect(insights.currentStreak, 2);
    expect(insights.focusedToday, isFalse);
  });

  test('sessions ended early do not extend the streak but count as focus time', () {
    final insights = Insights([
      session(day(0), minutes: 20, outcome: SessionOutcome.broken),
      session(day(1)),
    ], now);
    expect(insights.currentStreak, 1);
    expect(insights.todaySeconds, 20 * 60);
  });

  test('best streak spans month boundaries', () {
    final insights = Insights([
      session(DateTime(2026, 9, 29)),
      session(DateTime(2026, 9, 30)),
      session(DateTime(2026, 10, 1)),
      session(DateTime(2026, 10, 2)),
    ], now);
    expect(insights.bestStreak, 4);
    expect(insights.currentStreak, 4);
  });

  test('last days aggregate focus per day in chronological order', () {
    final insights = Insights([
      session(day(0), minutes: 25),
      session(day(0, 18), minutes: 45),
      session(day(6), minutes: 60),
      session(day(9), minutes: 90),
    ], now);
    final days = insights.lastDays(7);
    expect(days, hasLength(7));
    expect(days.first.seconds, 60 * 60);
    expect(days.last.seconds, 70 * 60);
    expect(insights.weekSeconds, 130 * 60);
    expect(insights.previousWeekSeconds, 90 * 60);
  });

  test('top apps merge blocked attempts across sessions', () {
    final insights = Insights([
      session(day(0), apps: {'a': 3, 'b': 1}),
      session(day(2), apps: {'a': 2, 'c': 5}),
      session(day(20), apps: {'b': 50}),
    ], now);
    final top = insights.topApps(7);
    expect(top.map((entry) => entry.key), ['a', 'c', 'b']);
    expect(top.first.value, 5);
    expect(insights.attemptsSince(7), 11);
  });

  test('completion rate reflects outcomes', () {
    final insights = Insights([
      session(day(0)),
      session(day(1), outcome: SessionOutcome.broken),
      session(day(2), outcome: SessionOutcome.interrupted),
      session(day(3)),
    ], now);
    expect(insights.completedCount, 2);
    expect(insights.completionRate, 50);
  });

  test('patterns find the best hour, the average and the longest session', () {
    final insights = Insights([
      session(day(1, 9), minutes: 60),
      session(day(2, 9), minutes: 30),
      session(day(3, 20), minutes: 20),
    ], now);
    expect(insights.bestHour, 9);
    expect(insights.averageSeconds, 2200);
    expect(insights.longestSeconds, 3600);
    expect(Insights(const [], now).bestHour, isNull);
  });

  test('today spans place sessions on the day line', () {
    final insights = Insights([session(day(0, 6), minutes: 60), session(day(1, 23), minutes: 120)], now);
    final spans = insights.todaySpans;
    expect(spans, hasLength(2));
    expect(spans.first.start, 0);
    expect(spans.first.end, closeTo(1 / 24, 1e-9));
    expect(spans.last.start, closeTo(6 / 24, 1e-9));
    expect(spans.last.end, closeTo(7 / 24, 1e-9));
  });
}
