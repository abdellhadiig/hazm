import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../platform/blocker.dart';
import 'app_state.dart';

class SessionController extends ChangeNotifier {
  SessionController(this.app);

  static const maxPlanned = Duration(hours: 4);

  final AppState app;
  final Stopwatch _drift = Stopwatch();
  final List<SessionRecord> _finished = [];
  SessionSnapshot? _snapshot;
  Timer? _poll;
  bool _foreground = true;
  bool _refreshing = false;
  bool _disposed = false;

  SessionSnapshot? get snapshot => _snapshot;

  bool get active => _snapshot != null;

  bool get hasFinished => _finished.isNotEmpty;

  Duration get planned => _snapshot?.planned ?? Duration.zero;

  Duration get elapsed {
    final snapshot = _snapshot;
    if (snapshot == null) return Duration.zero;
    final value = snapshot.elapsed + _drift.elapsed;
    return value > snapshot.planned ? snapshot.planned : value;
  }

  Duration get remaining => planned - elapsed;

  Duration get pauseRemaining {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.isPaused) return Duration.zero;
    final value = snapshot.pauseRemaining - _drift.elapsed;
    return value.isNegative ? Duration.zero : value;
  }

  bool get paused => pauseRemaining > Duration.zero;

  Duration get focused {
    final snapshot = _snapshot;
    if (snapshot == null) return Duration.zero;
    var pausedTotal = snapshot.paused;
    if (snapshot.isPaused) {
      final open = _drift.elapsed < snapshot.pauseRemaining ? _drift.elapsed : snapshot.pauseRemaining;
      pausedTotal += open;
    }
    final value = elapsed - pausedTotal;
    return value.isNegative ? Duration.zero : value;
  }

  double get progress {
    final total = planned.inMilliseconds;
    if (total <= 0) return 0;
    return (elapsed.inMilliseconds / total).clamp(0.0, 1.0);
  }

  int get attempts => _snapshot?.attempts ?? 0;

  bool get canExtend => active && planned + const Duration(minutes: 5) <= maxPlanned;

  String? get intention => _snapshot?.intention;

  String? get taskId => _snapshot?.taskId;

  DateTime get endsAt => DateTime.now().add(remaining);

  SessionRecord? takeFinished() => _finished.isEmpty ? null : _finished.removeAt(0);

  void setForeground(bool value) {
    _foreground = value;
    if (value) {
      refresh();
    } else {
      _poll?.cancel();
    }
  }

  Future<void> refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    try {
      _apply(await Blocker.session(), notify: false);
      final results = await Blocker.takeResults();
      for (final result in results) {
        _finished.add(app.record(result));
      }
    } finally {
      _refreshing = false;
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> start({required int minutes, String? taskId, String? intention}) async {
    final preferences = app.preferences;
    final snapshot = await Blocker.start(
      minutes: minutes,
      bonusThreshold: preferences.bonusThresholdMinutes,
      dnd: preferences.dnd,
      taskId: taskId,
      intention: intention,
    );
    if (snapshot == null) return false;
    _apply(snapshot);
    return true;
  }

  Future<void> takeBreak(int seconds) async {
    final snapshot = await Blocker.pause(seconds);
    if (snapshot != null) _apply(snapshot);
  }

  Future<void> resume() async {
    final snapshot = await Blocker.resume();
    if (snapshot != null) _apply(snapshot);
  }

  Future<bool> extend(int minutes) async {
    if (!canExtend) return false;
    final snapshot = await Blocker.extend(minutes);
    if (snapshot == null) return false;
    _apply(snapshot);
    return true;
  }

  Future<void> unlock() async {
    if (!active || !app.canUnlock) return;
    app.spendUnlock();
    await Blocker.breakSession();
    await refresh();
  }

  Future<void> cancel() async {
    await Blocker.cancelSession();
    _apply(null);
  }

  void _apply(SessionSnapshot? snapshot, {bool notify = true}) {
    _snapshot = snapshot;
    _drift
      ..reset()
      ..start();
    _schedule();
    if (notify && !_disposed) notifyListeners();
  }

  void _schedule() {
    _poll?.cancel();
    if (_snapshot == null || !_foreground || _disposed) return;
    final next = paused ? pauseRemaining : remaining;
    final wait = Duration(milliseconds: math.min(next.inMilliseconds, 4000) + 200);
    _poll = Timer(wait, refresh);
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
