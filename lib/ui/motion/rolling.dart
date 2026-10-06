import 'package:flutter/widgets.dart';

import '../../core/theme.dart';

class RollingText extends StatefulWidget {
  const RollingText(
    this.text, {
    super.key,
    required this.style,
    this.duration = Motion.medium,
    this.stagger = const Duration(milliseconds: 40),
  });

  final String text;
  final TextStyle style;
  final Duration duration;
  final Duration stagger;

  @override
  State<RollingText> createState() => _RollingTextState();
}

class _RollingTextState extends State<RollingText> {
  bool _rising = true;

  static int? _value(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  @override
  void didUpdateWidget(RollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    final before = _value(oldWidget.text);
    final after = _value(widget.text);
    _rising = before == null || after == null || after >= before;
  }

  @override
  Widget build(BuildContext context) {
    final glyphs = widget.text.characters.toList();
    final count = glyphs.length;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            _Glyph(
              key: ValueKey(count - i),
              glyph: glyphs[i],
              style: widget.style,
              rising: _rising,
              duration: widget.duration,
              delay: widget.stagger * (count - 1 - i),
            ),
        ],
      ),
    );
  }
}

class _Glyph extends StatefulWidget {
  const _Glyph({
    super.key,
    required this.glyph,
    required this.style,
    required this.rising,
    required this.duration,
    required this.delay,
  });

  final String glyph;
  final TextStyle style;
  final bool rising;
  final Duration duration;
  final Duration delay;

  @override
  State<_Glyph> createState() => _GlyphState();
}

class _GlyphState extends State<_Glyph> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1);
  String? _outgoing;
  bool _rising = true;
  double _lead = 0;

  @override
  void didUpdateWidget(_Glyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.glyph == widget.glyph) return;
    _outgoing = oldWidget.glyph;
    _rising = widget.rising;
    if (Motion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    final total = widget.delay + widget.duration;
    _lead = widget.delay.inMicroseconds / total.inMicroseconds;
    _controller
      ..duration = total
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = Text(widget.glyph, style: widget.style);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final outgoing = _outgoing;
        if (outgoing == null || _controller.isCompleted) return current;
        final linear = _lead >= 1 ? 1.0 : ((_controller.value - _lead) / (1 - _lead)).clamp(0.0, 1.0);
        final t = Motion.emphasized.transform(linear);
        final sign = _rising ? 1.0 : -1.0;
        final color = widget.style.color ?? const Color(0xFFFFFFFF);
        return ClipRect(
          child: Stack(
            children: [
              FractionalTranslation(
                translation: Offset(0, sign * (1 - t)),
                child: Text(widget.glyph, style: widget.style.copyWith(color: color.withOpacity(color.opacity * t))),
              ),
              Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(0, -sign * t),
                  child: Text(
                    outgoing,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: widget.style.copyWith(color: color.withOpacity(color.opacity * (1 - t))),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
