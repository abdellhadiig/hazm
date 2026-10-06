import 'dart:async';

import 'package:flutter/widgets.dart';

import '../platform/blocker.dart';

class GuardController extends ChangeNotifier with WidgetsBindingObserver {
  static const _dropGrace = Duration(seconds: 3);
  static const _watchEvery = Duration(milliseconds: 1500);

  BlockerStatus _status = const BlockerStatus();
  bool _loaded = false;
  bool _running = false;
  bool _attached = false;
  bool _disposed = false;
  Timer? _watcher;
  Timer? _drop;
  DateTime _watchUntil = DateTime.fromMillisecondsSinceEpoch(0);

  BlockerStatus get status => _status;

  bool get loaded => _loaded || !Blocker.available;

  bool get ready => !Blocker.available || _status.accessibility;

  bool get running => !Blocker.available || _running;

  bool get exposed => loaded && !running;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    Blocker.onStatus(_apply);
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<BlockerStatus> refresh() async {
    _apply(await Blocker.status());
    return _status;
  }

  void watch([Duration window = const Duration(minutes: 3)]) {
    _watchUntil = DateTime.now().add(window);
    _watcher ??= Timer.periodic(_watchEvery, (_) {
      if (_disposed || DateTime.now().isAfter(_watchUntil)) {
        unwatch();
        return;
      }
      refresh();
    });
  }

  void unwatch() {
    _watcher?.cancel();
    _watcher = null;
  }

  void _apply(BlockerStatus next) {
    if (_disposed) return;
    var changed = !_loaded || !next.sameAs(_status);
    _status = next;
    _loaded = true;
    if (next.running) {
      _drop?.cancel();
      _drop = null;
      if (!_running) {
        _running = true;
        changed = true;
      }
    } else if (_running) {
      _drop ??= Timer(_dropGrace, _settleDrop);
    }
    if (changed) notifyListeners();
  }

  void _settleDrop() {
    _drop = null;
    if (_disposed || _status.running || !_running) return;
    _running = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unwatch();
    _drop?.cancel();
    if (_attached) {
      WidgetsBinding.instance.removeObserver(this);
      Blocker.onStatus(null);
    }
    super.dispose();
  }
}
