import 'models.dart';

class DayFocus {
  const DayFocus(this.day, this.seconds);

  final DateTime day;
  final int seconds;
}

class DaySpan {
  const DaySpan(this.start, this.end, this.outcome);

  final double start;
  final double end;
  final SessionOutcome outcome;
}

class Insights {
  Insights(this.sessions, this.now) {
    for (final session in sessions) {
      final key = dayKey(session.startedAt);
      _secondsByDay.update(key, (value) => value + session.focusedSeconds, ifAbsent: () => session.focusedSeconds);
      if (session.completed) _completedDays.add(key);
    }
  }

  static const patternDays = 30;

  final List<SessionRecord> sessions;
  final DateTime now;
  final Map<String, int> _secondsByDay = {};
  final Set<String> _completedDays = {};

  DateTime get today => DateTime(now.year, now.month, now.day);

  DateTime dayOffset(int days) => DateTime(now.year, now.month, now.day - days);

  int secondsOn(DateTime day) => _secondsByDay[dayKey(day)] ?? 0;

  int get todaySeconds => secondsOn(today);

  List<DayFocus> lastDays(int count) => [
        for (var offset = count - 1; offset >= 0; offset--) DayFocus(dayOffset(offset), secondsOn(dayOffset(offset))),
      ];

  int secondsBetween(int fromOffset, int toOffset) {
    var total = 0;
    for (var offset = fromOffset; offset <= toOffset; offset++) {
      total += secondsOn(dayOffset(offset));
    }
    return total;
  }

  int get weekSeconds => secondsBetween(0, 6);

  int get previousWeekSeconds => secondsBetween(7, 13);

  int get currentStreak {
    var offset = _completedDays.contains(dayKey(today)) ? 0 : 1;
    var streak = 0;
    while (_completedDays.contains(dayKey(dayOffset(offset)))) {
      streak++;
      offset++;
    }
    return streak;
  }

  int get bestStreak {
    if (_completedDays.isEmpty) return 0;
    final days = _completedDays.map(DateTime.parse).toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final previous = days[i - 1];
      final expected = DateTime(previous.year, previous.month, previous.day + 1);
      run = days[i] == expected ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  bool get focusedToday => _completedDays.contains(dayKey(today));

  int get completedCount => sessions.where((session) => session.completed).length;

  int get completionRate {
    if (sessions.isEmpty) return 0;
    return (completedCount * 100 / sessions.length).round();
  }

  Iterable<SessionRecord> _since(int days) {
    final start = dayOffset(days - 1);
    return sessions.where((session) => !session.startedAt.isBefore(start));
  }

  int attemptsSince(int days) => _since(days).fold(0, (sum, session) => sum + session.attempts);

  List<MapEntry<String, int>> topApps(int days, {int limit = 5}) {
    final counts = <String, int>{};
    for (final session in _since(days)) {
      session.apps.forEach((name, count) => counts.update(name, (value) => value + count, ifAbsent: () => count));
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  late final List<double> hourly = _hourly();

  List<double> _hourly() {
    final buckets = List<double>.filled(24, 0);
    for (final session in _since(patternDays)) {
      final span = session.endedAt.difference(session.startedAt).inSeconds;
      if (span <= 0 || session.focusedSeconds <= 0) continue;
      final ratio = session.focusedSeconds / span;
      var cursor = session.startedAt;
      while (cursor.isBefore(session.endedAt)) {
        final next = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour + 1);
        final end = next.isBefore(session.endedAt) ? next : session.endedAt;
        buckets[cursor.hour] += end.difference(cursor).inSeconds * ratio;
        cursor = end;
      }
    }
    return buckets;
  }

  late final int? bestHour = _bestHour();

  int? _bestHour() {
    var best = -1;
    var peak = 0.0;
    for (var hour = 0; hour < 24; hour++) {
      if (hourly[hour] > peak) {
        peak = hourly[hour];
        best = hour;
      }
    }
    return best < 0 ? null : best;
  }

  late final int averageSeconds = _average();

  int _average() {
    final focused = _since(patternDays).where((session) => session.focusedSeconds > 0).toList();
    if (focused.isEmpty) return 0;
    return focused.fold(0, (sum, session) => sum + session.focusedSeconds) ~/ focused.length;
  }

  late final int longestSeconds =
      sessions.fold(0, (best, session) => session.focusedSeconds > best ? session.focusedSeconds : best);

  late final List<DaySpan> todaySpans = _todaySpans();

  List<DaySpan> _todaySpans() {
    final start = today;
    final end = DateTime(start.year, start.month, start.day + 1);
    final length = end.difference(start).inSeconds;
    final spans = <DaySpan>[];
    for (final session in sessions) {
      if (!session.endedAt.isAfter(start) || !session.startedAt.isBefore(end)) continue;
      final from = session.startedAt.isBefore(start) ? start : session.startedAt;
      final to = session.endedAt.isAfter(end) ? end : session.endedAt;
      spans.add(
        DaySpan(
          from.difference(start).inSeconds / length,
          to.difference(start).inSeconds / length,
          session.outcome,
        ),
      );
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }
}
