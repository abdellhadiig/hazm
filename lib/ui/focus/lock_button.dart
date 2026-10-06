import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../motion/effects.dart';

enum LockMode { idle, locked, paused }

class LockButton extends StatefulWidget {
  const LockButton({
    super.key,
    required this.mode,
    required this.onLock,
    required this.onResume,
    required this.onLockedTap,
  });

  static const width = 200.0;
  static const height = 60.0;

  final LockMode mode;
  final VoidCallback onLock;
  final VoidCallback onResume;
  final VoidCallback onLockedTap;

  @override
  State<LockButton> createState() => _LockButtonState();
}

class _LockButtonState extends State<LockButton> with TickerProviderStateMixin {
  static const _quickFraction = 0.35;

  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    reverseDuration: const Duration(milliseconds: 260),
  )
    ..addListener(_onProgress)
    ..addStatusListener(_onHold);
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  bool _pressed = false;
  bool _hint = false;
  int _ticks = 0;
  int _shock = 0;
  int _shake = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(LockButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == widget.mode) return;
    if (oldWidget.mode == LockMode.idle && widget.mode == LockMode.locked) _shock++;
    _hold.value = 0;
    _hint = false;
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.mode == LockMode.locked) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  void _onProgress() {
    if (_hold.status != AnimationStatus.forward) return;
    final step = (_hold.value * 3).floor();
    if (step > _ticks && step < 3) {
      _ticks = step;
      Haptics.selection();
    }
  }

  void _onHold(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    Haptics.heavy();
    widget.onLock();
    _settleLater();
  }

  void _settleLater() {
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_pressed && widget.mode == LockMode.idle && _hold.value > 0) _hold.reverse();
    });
  }

  void _down() {
    if (!mounted || widget.mode != LockMode.idle) return;
    _ticks = 0;
    Haptics.light();
    setState(() {
      _pressed = true;
      _hint = false;
    });
    _hold.forward();
  }

  void _up() {
    if (!mounted || !_pressed) return;
    setState(() => _pressed = false);
    if (_hold.status == AnimationStatus.completed) {
      _settleLater();
      return;
    }
    final quick = _hold.value < _quickFraction;
    _hold.reverse();
    if (quick && widget.mode == LockMode.idle) _showHint();
  }

  void _showHint() {
    _hintTimer?.cancel();
    setState(() {
      _hint = true;
      _shake++;
    });
    _hintTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _hint = false);
    });
  }

  void _tap() {
    switch (widget.mode) {
      case LockMode.idle:
        return;
      case LockMode.paused:
        Haptics.medium();
        widget.onResume();
      case LockMode.locked:
        Haptics.light();
        widget.onLockedTap();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hold.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mode = widget.mode;
    final (icon, label) = switch (mode) {
      LockMode.idle => (Icons.lock_outline, l.t('lockIn')),
      LockMode.locked => (Icons.lock, l.t('locked')),
      LockMode.paused => (Icons.play_arrow_rounded, l.t('resume')),
    };
    return Semantics(
      button: true,
      label: label,
      onTap: switch (mode) {
        LockMode.idle => widget.onLock,
        LockMode.paused => widget.onResume,
        LockMode.locked => widget.onLockedTap,
      },
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Shake(
            trigger: _shake,
            child: Shockwave(
              trigger: _shock,
              child: GestureDetector(
                onTap: mode == LockMode.idle ? null : _tap,
                child: Listener(
                  onPointerDown: (_) => _down(),
                  onPointerUp: (_) => _up(),
                  onPointerCancel: (_) => _up(),
                  child: RepaintBoundary(
                    child: AnimatedScale(
                      scale: _pressed ? 0.97 : 1,
                      duration: Motion.fast,
                      curve: Motion.ease,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_hold, _pulse]),
                        builder: (context, _) => _face(icon, label, mode),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: 0,
            bottom: LockButton.height + Space.md,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                switchInCurve: Motion.emphasized,
                switchOutCurve: Motion.exit,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child:
                    _hint ? _HintBubble(key: const ValueKey('hint'), text: l.t('holdHint')) : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _face(IconData icon, String label, LockMode mode) {
    final fill = Curves.easeInOut.transform(_hold.value);
    final glow = mode == LockMode.locked ? _pulse.value : 0.0;
    return Container(
      width: LockButton.width,
      height: LockButton.height,
      decoration: BoxDecoration(
        color: Palette.primary,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: [
          if (mode == LockMode.locked)
            BoxShadow(
              color: Palette.primary.withOpacity(0.26 + glow * 0.3),
              blurRadius: 18 + glow * 18,
              spreadRadius: glow * 5,
            )
          else if (fill > 0)
            BoxShadow(color: Palette.primary.withOpacity(0.45 * fill), blurRadius: 26 * fill),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (fill > 0)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: fill,
                  heightFactor: 1,
                  child: const ColoredBox(color: Palette.primaryDark),
                ),
              ),
            if (fill > 0 && fill < 1)
              Align(
                alignment: AlignmentDirectional(fill * 2 - 1, 0),
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    color: Palette.primaryGlow,
                    boxShadow: [BoxShadow(color: Palette.primaryGlow, blurRadius: 14, spreadRadius: 1)],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    switchInCurve: Motion.spring,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(icon, key: ValueKey(icon), color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: Space.sm),
                  Flexible(child: _RollingLabel(label)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RollingLabel extends StatelessWidget {
  const _RollingLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(label);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: Motion.slow,
        switchInCurve: Motion.emphasized,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, animation) {
          final incoming = child.key == key;
          final from = incoming ? const Offset(0, 0.9) : const Offset(0, -0.9);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: Tween(begin: from, end: Offset.zero).animate(animation), child: child),
          );
        },
        child: FittedBox(
          key: key,
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
        ),
      ),
    );
  }
}

class _HintBubble extends StatelessWidget {
  const _HintBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm + 2),
        decoration: BoxDecoration(
          color: Palette.surfaceLight,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: Palette.primary.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app_outlined, size: 16, color: Palette.primary),
            const SizedBox(width: Space.sm),
            Flexible(child: Text(text, style: Typo.small.copyWith(color: Colors.white, height: 1.35))),
          ],
        ),
      ),
    );
  }
}
