import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/insights.dart';
import '../../data/models.dart';
import '../motion/reveal.dart';
import '../widgets/kit.dart';

class Replay extends StatelessWidget {
  const Replay({super.key, required this.builder, this.duration = Motion.long, this.curve = Motion.emphasized});

  final Widget Function(BuildContext context, double progress) builder;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(RevealScope.of(context)),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.reduced(context) ? Duration.zero : duration,
      curve: curve,
      builder: (context, value, _) => builder(context, value),
    );
  }
}

class WeekChart extends StatelessWidget {
  const WeekChart({super.key, required this.days});

  final List<DayFocus> days;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final peak = math.max(60, days.fold<int>(0, (value, day) => math.max(value, day.seconds)));
    return Replay(
      duration: const Duration(milliseconds: 1100),
      curve: Curves.linear,
      builder: (context, progress) => SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < days.length; index++)
              Expanded(
                child: _Bar(
                  minutes: (days[index].seconds / 60).round(),
                  fraction: days[index].seconds / peak,
                  growth: Motion.emphasized.transform(((progress * 1.6) - index * 0.09).clamp(0.0, 1.0)),
                  label: l.weekday(days[index].day.weekday),
                  today: index == days.length - 1,
                  unit: l.t('unitM'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.minutes,
    required this.fraction,
    required this.growth,
    required this.label,
    required this.today,
    required this.unit,
  });

  final int minutes;
  final double fraction;
  final double growth;
  final String label;
  final bool today;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs + 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Opacity(
            opacity: growth,
            child: Text(
              '${(minutes * growth).round()}$unit',
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: minutes > 0 ? Colors.white : Palette.textFaint,
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          Container(
            height: math.max(4, fraction.clamp(0.0, 1.0) * 100 * growth),
            decoration: BoxDecoration(
              color: today ? Palette.primary : Palette.textFaint,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xs)),
              boxShadow: today && minutes > 0
                  ? [BoxShadow(color: Palette.primary.withOpacity(0.35 * growth), blurRadius: 12)]
                  : null,
            ),
          ),
          const SizedBox(height: Space.xs),
          Caps(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: today ? Palette.primary : Palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.spans, required this.now});

  final List<DaySpan> spans;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final position = (now.hour * 3600 + now.minute * 60 + now.second) / 86400;
    const marks = TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Palette.textFaint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Replay(
          duration: const Duration(milliseconds: 1200),
          builder: (context, progress) => SizedBox(
            height: 14,
            child: CustomPaint(painter: _TimelinePainter(spans, position, progress, rtl)),
          ),
        ),
        const SizedBox(height: Space.xs + 2),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final hour in rtl ? const ['24', '18', '12', '06', '00'] : const ['00', '06', '12', '18', '24'])
                Text(hour, style: marks),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter(this.spans, this.now, this.progress, this.rtl);

  final List<DaySpan> spans;
  final double now;
  final double progress;
  final bool rtl;

  double _x(Size size, double fraction) => (rtl ? 1 - fraction : fraction) * size.width;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height / 2 - 3, size.width, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(track, Paint()..color = Palette.surfaceLight);
    for (var hour = 1; hour < 24; hour++) {
      final x = _x(size, hour / 24);
      canvas.drawLine(
        Offset(x, size.height / 2 - (hour % 6 == 0 ? 6 : 2)),
        Offset(x, size.height / 2 + (hour % 6 == 0 ? 6 : 2)),
        Paint()
          ..color = Palette.background.withOpacity(hour % 6 == 0 ? 0.9 : 0.6)
          ..strokeWidth = 1,
      );
    }
    final reach = Motion.emphasized.transform(progress);
    for (final span in spans) {
      if (span.start > reach) continue;
      final end = math.min(span.end, reach);
      final color = switch (span.outcome) {
        SessionOutcome.completed => Palette.primary,
        SessionOutcome.broken => Palette.danger,
        SessionOutcome.interrupted => Palette.warning,
      };
      final left = math.min(_x(size, span.start), _x(size, end));
      final right = math.max(_x(size, span.start), _x(size, end));
      final rect = Rect.fromLTRB(left, size.height / 2 - 3, math.max(right, left + 3), size.height / 2 + 3);
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(4)),
          Paint()
            ..color = color.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        )
        ..drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), Paint()..color = color);
    }
    final marker = _x(size, now);
    canvas.drawLine(
      Offset(marker, 0),
      Offset(marker, size.height),
      Paint()
        ..color = Colors.white.withOpacity(0.85 * progress)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.now != now ||
      oldDelegate.rtl != rtl ||
      oldDelegate.spans != spans;
}

class FocusHeatmap extends StatelessWidget {
  const FocusHeatmap({super.key, required this.insights, this.weeks = 16});

  final Insights insights;
  final int weeks;

  static Color shade(int seconds) {
    if (seconds <= 0) return Palette.surfaceLight;
    if (seconds < 25 * 60) return Palette.primary.withOpacity(0.3);
    if (seconds < 60 * 60) return Palette.primary.withOpacity(0.55);
    if (seconds < 120 * 60) return Palette.primary.withOpacity(0.8);
    return Palette.primary;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final today = insights.today;
    final shift = (today.weekday % 7 - firstDay + 7) % 7;
    final start = DateTime(today.year, today.month, today.day - shift - (weeks - 1) * 7);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const legend = TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Palette.textMuted);
    final cells = [
      for (var week = 0; week < weeks; week++)
        for (var day = 0; day < 7; day++)
          () {
            final date = DateTime(start.year, start.month, start.day + week * 7 + day);
            return _HeatCell(
              week: week,
              day: day,
              color: date.isAfter(today) ? null : shade(insights.secondsOn(date)),
              today: date == today,
            );
          }(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 4.0;
            final cell = ((constraints.maxWidth - gap * (weeks - 1)) / weeks).clamp(8.0, 22.0);
            return SizedBox(
              height: cell * 7 + gap * 6,
              child: Replay(
                duration: const Duration(milliseconds: 1300),
                curve: Curves.linear,
                builder: (context, progress) => CustomPaint(
                  painter: _HeatPainter(cells, weeks, cell, gap, progress, rtl),
                  size: Size.infinite,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: Space.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Caps(l.t('less'), style: legend),
            const SizedBox(width: Space.sm),
            for (final seconds in const [0, 600, 2400, 4800, 9000]) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: shade(seconds), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 3),
            ],
            const SizedBox(width: Space.xs),
            Caps(l.t('more'), style: legend),
          ],
        ),
      ],
    );
  }
}

class _HeatCell {
  const _HeatCell({required this.week, required this.day, required this.color, required this.today});

  final int week;
  final int day;
  final Color? color;
  final bool today;
}

class _HeatPainter extends CustomPainter {
  const _HeatPainter(this.cells, this.weeks, this.cell, this.gap, this.progress, this.rtl);

  final List<_HeatCell> cells;
  final int weeks;
  final double cell;
  final double gap;
  final double progress;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final spacing = weeks > 1 ? (size.width - cell * weeks) / (weeks - 1) : 0.0;
    final span = weeks + 6.0;
    for (final item in cells) {
      final color = item.color;
      if (color == null) continue;
      final wave = ((progress * (span + 6) - (item.week + item.day)) / 6).clamp(0.0, 1.0);
      if (wave <= 0) continue;
      final eased = Motion.emphasized.transform(wave);
      final column = rtl ? weeks - 1 - item.week : item.week;
      final center = Offset(column * (cell + spacing) + cell / 2, item.day * (cell + gap) + cell / 2);
      final side = cell * (0.5 + 0.5 * eased);
      final rect = Rect.fromCenter(center: center, width: side, height: side);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      canvas.drawRRect(rrect, Paint()..color = color.withOpacity(color.opacity * eased));
      if (item.today) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withOpacity(eased),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.cells != cells ||
      oldDelegate.cell != cell ||
      oldDelegate.rtl != rtl;
}
