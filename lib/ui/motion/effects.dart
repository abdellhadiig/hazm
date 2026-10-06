import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration = Motion.long,
    this.curve = Curves.easeOutQuart,
  });

  final num value;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: Motion.reduced(context) ? Duration.zero : duration,
      curve: curve,
      builder: (context, current, _) => builder(context, current),
    );
  }
}

class Shockwave extends StatefulWidget {
  const Shockwave({
    super.key,
    required this.trigger,
    required this.child,
    this.color = Palette.primary,
    this.radius = Radii.lg,
    this.spread = 56,
  });

  final int trigger;
  final Widget child;
  final Color color;
  final double radius;
  final double spread;

  @override
  State<Shockwave> createState() => _ShockwaveState();
}

class _ShockwaveState extends State<Shockwave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void didUpdateWidget(Shockwave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && !Motion.reduced(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _RingPainter(
        progress: _controller,
        color: widget.color,
        radius: widget.radius,
        spread: widget.spread,
      ),
      child: widget.child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.radius, required this.spread})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final double radius;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value;
    if (value <= 0 || value >= 1) return;
    final bounds = Offset.zero & size;
    for (final (lag, weight) in const [(0.0, 1.0), (0.2, 0.45)]) {
      final local = ((value - lag) / (1 - lag)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final grow = spread * eased;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - eased) + 0.5
        ..color = color.withOpacity((1 - local) * (1 - local) * 0.7 * weight);
      canvas.drawRRect(RRect.fromRectAndRadius(bounds.inflate(grow), Radius.circular(radius + grow)), paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius || oldDelegate.spread != spread;
}

class DrawnCheck extends StatelessWidget {
  const DrawnCheck({super.key, required this.progress, this.color = Palette.success, this.size = 56, this.stroke = 5});

  final double progress;
  final Color color;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CheckPainter(progress.clamp(0.0, 1.0), color, stroke)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.progress, this.color, this.stroke);

  final double progress;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.53)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.82, size.height * 0.3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke
      ..color = color;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.stroke != stroke;
}

class Starburst extends StatelessWidget {
  const Starburst({super.key, required this.progress, this.color = Palette.primary, this.rays = 14, this.size = 180});

  final double progress;
  final Color color;
  final int rays;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BurstPainter(progress.clamp(0.0, 1.0), color, rays)),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.progress, this.color, this.rays);

  final double progress;
  final Color color;
  final int rays;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final reach = size.shortestSide / 2;
    final head = Curves.easeOutCubic.transform(progress);
    final tail = Curves.easeInCubic.transform(progress);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = color.withOpacity(1 - progress);
    for (var i = 0; i < rays; i++) {
      final angle = i * 2 * math.pi / rays + (i.isEven ? 0 : math.pi / rays / 2);
      final direction = Offset(math.cos(angle), math.sin(angle));
      final length = i.isEven ? 1.0 : 0.72;
      canvas.drawLine(
        center + direction * reach * (0.38 + 0.62 * tail) * length,
        center + direction * reach * (0.42 + 0.58 * head) * length,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.rays != rays;
}

class Breathing extends StatefulWidget {
  const Breathing({
    super.key,
    required this.builder,
    this.enabled = true,
    this.period = const Duration(milliseconds: 2400),
  });

  final Widget Function(BuildContext context, double value) builder;
  final bool enabled;
  final Duration period;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Breathing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _sync();
  }

  void _sync() {
    if (widget.enabled) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, Curves.easeInOut.transform(_controller.value)),
    );
  }
}

class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child, this.distance = 7});

  final int trigger;
  final Widget child;
  final double distance;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && !Motion.reduced(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        if (t == 0 || t == 1) return child!;
        final dx = math.sin(t * math.pi * 6) * widget.distance * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

class Delayed extends StatefulWidget {
  const Delayed({super.key, required this.delay, required this.builder});

  final Duration delay;
  final Widget Function(BuildContext context, bool ready) builder;

  @override
  State<Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<Delayed> {
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ready);
}
