import 'package:flutter/widgets.dart';

import '../../core/theme.dart';

class RevealScope extends InheritedWidget {
  const RevealScope({super.key, required this.generation, required super.child});

  final int generation;

  static int of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RevealScope>()?.generation ?? 0;

  @override
  bool updateShouldNotify(RevealScope oldWidget) => oldWidget.generation != generation;
}

class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.offset = const Offset(0, 18),
    this.scale = 1,
  });

  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double scale;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final Duration _lead = widget.delay + Motion.stagger * widget.index;
  late final AnimationController _controller = AnimationController(vsync: this, duration: _lead + widget.duration);
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(_lead.inMicroseconds / (_lead + widget.duration).inMicroseconds, 1, curve: Motion.enter),
  );
  int? _generation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final generation = RevealScope.of(context);
    if (generation == _generation) return;
    _generation = generation;
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final offset = rtl ? Offset(-widget.offset.dx, widget.offset.dy) : widget.offset;
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (context, child) {
          final remaining = 1 - _progress.value;
          if (remaining == 0) return child!;
          final moved = Transform.translate(offset: offset * remaining, child: child);
          if (widget.scale == 1) return moved;
          return Transform.scale(scale: 1 - (1 - widget.scale) * remaining, child: moved);
        },
      ),
    );
  }
}
