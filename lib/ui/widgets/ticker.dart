import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class SecondTicker extends StatefulWidget {
  const SecondTicker({super.key, required this.read, required this.builder, this.enabled = true});

  final int Function() read;
  final Widget Function(BuildContext context, int value) builder;
  final bool enabled;

  @override
  State<SecondTicker> createState() => _SecondTickerState();
}

class _SecondTickerState extends State<SecondTicker> {
  late int _value = widget.read();
  ValueListenable<bool>? _visible;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.getNotifier(context);
  }

  @override
  void didUpdateWidget(SecondTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _value = widget.read();
    if (oldWidget.enabled != widget.enabled) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = widget.enabled ? Timer.periodic(const Duration(milliseconds: 200), (_) => _tick()) : null;
  }

  void _tick() {
    if (!mounted || _visible?.value == false) return;
    final next = widget.read();
    if (next != _value) setState(() => _value = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
