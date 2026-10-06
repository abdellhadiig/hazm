import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../motion/rolling.dart';
import '../widgets/kit.dart';

class BigClock extends StatelessWidget {
  const BigClock({
    super.key,
    required this.seconds,
    required this.caption,
    this.accent = Palette.primary,
    this.size = 120,
  });

  final int seconds;
  final String caption;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = Fmt.parts(seconds);
    final scale = size / 120;
    return Semantics(
      label: '${Fmt.clock(Duration(seconds: seconds))} $caption',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            widthFactor: 1,
            heightFactor: 0.86,
            child: RollingText(
              parts.main,
              duration: Motion.slow,
              style: Typo.numeral.copyWith(fontSize: size, height: 1, letterSpacing: -4 * scale),
            ),
          ),
          if (parts.minor.isNotEmpty)
            RollingText(
              parts.minor,
              style: Typo.numeral.copyWith(
                fontSize: 36 * scale,
                height: 1.05,
                color: Palette.textMuted,
                letterSpacing: -1,
              ),
            ),
          if (parts.trace.isNotEmpty)
            RollingText(
              parts.trace,
              duration: Motion.fast,
              style: Typo.numeral.copyWith(
                fontSize: 20 * scale,
                height: 1.1,
                color: Palette.textFaint,
                letterSpacing: -1,
              ),
            ),
          const SizedBox(height: Space.sm),
          _Caption(text: caption, accent: accent),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.reduced(context) ? Duration.zero : Motion.long,
      curve: Motion.emphasized,
      builder: (context, progress, child) => CustomPaint(
        painter: _Underline(progress: progress, color: accent, fromRight: !rtl),
        child: Opacity(opacity: Curves.easeOut.transform(progress), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: Space.sm + 2),
        child: Caps(
          text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: accent),
        ),
      ),
    );
  }
}

class _Underline extends CustomPainter {
  const _Underline({required this.progress, required this.color, required this.fromRight});

  final double progress;
  final Color color;
  final bool fromRight;

  @override
  void paint(Canvas canvas, Size size) {
    final length = size.width * progress;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final start = fromRight ? size.width : 0.0;
    final end = fromRight ? size.width - length : length;
    canvas.drawLine(Offset(start, 1), Offset(end, 1), paint);
  }

  @override
  bool shouldRepaint(_Underline oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.fromRight != fromRight;
}
