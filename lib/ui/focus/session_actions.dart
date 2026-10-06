import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../platform/blocker.dart';
import '../../state/scope.dart';
import '../../state/session_controller.dart';
import '../motion/reveal.dart';
import '../pushup/pushup_screen.dart';
import '../widgets/app_icon.dart';
import '../widgets/dialogs.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';
import '../widgets/sheet.dart';
import '../widgets/ticker.dart';

enum UnlockChoice { pushUps, unlock }

Future<void> earnBreak(BuildContext context) async {
  final app = context.app;
  final session = context.session;
  final l = context.l10n;
  final required = app.requiredPushUps;
  final secondsEach = app.preferences.pushUpSeconds;
  final count = await Navigator.of(context).push<int>(
    MaterialPageRoute(builder: (_) => PushUpScreen(required: required, secondsEach: secondsEach)),
  );
  if (count == null || count <= 0 || !context.mounted) return;
  app.addPushUps(count);
  if (count < required) {
    showToast(context, l.f('pushUpsTooFew', {'count': '$required'}), icon: Icons.fitness_center);
    return;
  }
  final seconds = count * secondsEach;
  await session.takeBreak(seconds);
  if (!context.mounted) return;
  showToast(context, l.f('breakEarned', {'time': Fmt.duration(l, seconds)}), icon: Icons.coffee_outlined);
}

Future<bool> showUnlockOptions(BuildContext context, {BlockedApp? blocked}) async {
  final choice = await showHazmSheet<UnlockChoice>(
    context,
    title: (l) => l.t('unlockOptions'),
    scrollable: false,
    builder: (_) => _UnlockOptions(blocked: blocked),
  );
  if (choice == null || !context.mounted) return false;
  switch (choice) {
    case UnlockChoice.pushUps:
      await earnBreak(context);
      return false;
    case UnlockChoice.unlock:
      if (!context.session.active || !context.app.canUnlock) return false;
      await context.session.unlock();
      return true;
  }
}

class _UnlockOptions extends StatefulWidget {
  const _UnlockOptions({this.blocked});

  final BlockedApp? blocked;

  @override
  State<_UnlockOptions> createState() => _UnlockOptionsState();
}

class _UnlockOptionsState extends State<_UnlockOptions> {
  late final SessionController _session = context.session;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_check);
  }

  @override
  void dispose() {
    _session.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_closing || !mounted || (_session.active && !_session.paused)) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  void _choose(UnlockChoice choice) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final app = context.app;
    final blocked = widget.blocked;
    return SheetLayout(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (blocked != null) ...[
            Reveal(child: _BlockedTag(app: blocked)),
            const SizedBox(height: Space.lg),
          ],
          const Reveal(index: 1, child: _Standing()),
          const SizedBox(height: Space.xl),
          Reveal(
            index: 2,
            child: _BreakOption(
              count: app.requiredPushUps,
              seconds: app.preferences.pushUpSeconds,
              onTap: () => _choose(UnlockChoice.pushUps),
            ),
          ),
          const SizedBox(height: Space.md),
          Reveal(index: 3, child: _UnlockOption(onConfirmed: () => _choose(UnlockChoice.unlock))),
        ],
      ),
      footer: BlockButton(
        label: l.t('keepFocusing'),
        icon: Icons.lock,
        onTap: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _BlockedTag extends StatelessWidget {
  const _BlockedTag({required this.app});

  final BlockedApp app;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        ColorFiltered(colorFilter: _grayscale, child: AppIcon(app.package, size: 28, label: app.label)),
        const SizedBox(width: Space.sm + 2),
        Expanded(
          child: Caps(
            l.f('appBlocked', {'app': l.isArabic ? app.label : app.label.toUpperCase()}),
            style: Typo.eyebrow.copyWith(fontSize: 11, color: Palette.primary),
          ),
        ),
      ],
    );
  }
}

class _Standing extends StatelessWidget {
  const _Standing();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.session;
    return SecondTicker(
      read: () => Fmt.ceilSeconds(session.remaining),
      builder: (context, seconds) {
        final intention = session.intention;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          Fmt.clock(Duration(seconds: seconds)),
                          textDirection: TextDirection.ltr,
                          style: Typo.numeral.copyWith(fontSize: 44, height: 1, letterSpacing: -1.5),
                        ),
                        const SizedBox(width: Space.sm),
                        Caps(l.t('leftLabel'), style: Typo.eyebrow.copyWith(color: Palette.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        Fmt.pct(l, (session.progress * 100).round()),
                        textDirection: TextDirection.ltr,
                        style: Typo.numeral.copyWith(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                      ),
                      const SizedBox(width: Space.xs + 1),
                      Caps(l.t('doneCaption'), style: Typo.statLabel),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            _Track(progress: session.progress),
            if (intention != null) ...[
              const SizedBox(height: Space.md),
              Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 14, color: Palette.primary),
                  const SizedBox(width: Space.xs + 2),
                  Expanded(child: Text(intention, maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.item)),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      height: 10,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: Motion.reduced(context) ? Duration.zero : Motion.long,
        curve: Motion.emphasized,
        builder: (context, value, _) => CustomPaint(painter: _TrackPainter(progress: value, rtl: rtl)),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.progress, required this.rtl});

  final double progress;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final base = Paint()
      ..color = Palette.divider
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), base);
    if (progress <= 0) return;
    final start = rtl ? size.width : 0.0;
    final end = start + (rtl ? -1 : 1) * size.width * progress;
    final fill = Paint()
      ..color = Palette.primary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(start, y), Offset(end, y), fill)
      ..drawCircle(
        Offset(end, y),
        5,
        Paint()
          ..color = Palette.primary.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(Offset(end, y), 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.rtl != rtl;
}

class _OptionHead extends StatelessWidget {
  const _OptionHead({required this.number, required this.title, required this.color, required this.trailing});

  final String number;
  final String title;
  final Color color;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(number, style: Typo.numeral.copyWith(fontSize: 12, color: color)),
        const SizedBox(width: Space.sm + 2),
        Container(width: 1, height: 12, color: color.withOpacity(0.4)),
        const SizedBox(width: Space.sm + 2),
        Expanded(
          child: Caps(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: color),
          ),
        ),
        const SizedBox(width: Space.sm),
        trailing,
      ],
    );
  }
}

class _BreakOption extends StatelessWidget {
  const _BreakOption({required this.count, required this.seconds, required this.onTap});

  final int count;
  final int seconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: Palette.surfaceLight.withOpacity(0.4),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: Palette.primary.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OptionHead(
              number: '01',
              title: l.t('optionPushUps'),
              color: Palette.primary,
              trailing: const Icon(Icons.arrow_forward, size: 18, color: Palette.primary),
            ),
            const SizedBox(height: Space.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Figure(value: '$count', label: l.t('pushUpsLabel'), color: Colors.white),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Caps(
                          l.f('perPushUp', {'seconds': '$seconds'}),
                          textAlign: TextAlign.center,
                          style: Typo.statLabel.copyWith(color: Palette.textSecondary),
                        ),
                        const SizedBox(height: Space.xs),
                        const _Flow(),
                      ],
                    ),
                  ),
                ),
                _Figure(
                  value: Fmt.clock(Duration(seconds: count * seconds)),
                  label: l.t('breakLabel'),
                  color: Palette.primary,
                  end: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, required this.color, this.end = false});

  final String value;
  final String label;
  final Color color;
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: Typo.numeral.copyWith(fontSize: 30, height: 1, letterSpacing: -1, color: color),
        ),
        const SizedBox(height: Space.xs + 2),
        Caps(label, style: Typo.statLabel),
      ],
    );
  }
}

class _Flow extends StatefulWidget {
  const _Flow();

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
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
    return SizedBox(
      height: 12,
      child: CustomPaint(painter: _FlowPainter(progress: _controller, rtl: rtl)),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({required this.progress, required this.rtl}) : super(repaint: progress);

  final Animation<double> progress;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final width = size.width - 8;
    if (width <= 0) return;
    double x(double t) => rtl ? size.width - t * width : t * width;
    final dash = Paint()
      ..color = Palette.textFaint
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var t = 0.0; t < 1; t += 0.08) {
      canvas.drawLine(Offset(x(t), y), Offset(x(math.min(t + 0.035, 1)), y), dash);
    }
    final head = Curves.easeInOutCubic.transform(progress.value);
    final tail = (head - 0.22).clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(x(tail), y),
      Offset(x(head), y),
      Paint()
        ..shader = LinearGradient(colors: [Palette.primary.withOpacity(0), Palette.primary])
            .createShader(Rect.fromPoints(Offset(x(tail), y - 1), Offset(x(head), y + 1)))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(x(head), y), 3, Paint()..color = Palette.primary);
    final tip = x(1) + (rtl ? -8 : 8);
    final back = x(1);
    final arrow = Path()
      ..moveTo(back, y - 4)
      ..lineTo(tip, y)
      ..lineTo(back, y + 4);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = Palette.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FlowPainter oldDelegate) => oldDelegate.rtl != rtl || oldDelegate.progress != progress;
}

class _UnlockOption extends StatelessWidget {
  const _UnlockOption({required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final app = context.app;
    final available = app.canUnlock;
    final credits = app.wallet.available;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: Palette.surfaceLight.withOpacity(0.4),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Palette.danger.withOpacity(available ? 0.35 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OptionHead(
            number: '02',
            title: l.t('optionUnlock'),
            color: Palette.danger,
            trailing: _Credits(count: credits),
          ),
          const SizedBox(height: Space.sm + 2),
          Text(l.t('unlockEndsBody'), style: Typo.small.copyWith(color: Palette.textSecondary, height: 1.5)),
          const SizedBox(height: Space.lg),
          if (available) ...[
            _HoldToUnlock(onConfirmed: onConfirmed),
            const SizedBox(height: Space.sm + 2),
            Caps(
              '${l.f('creditsPill', {'count': '$credits'})}  ·  ${l.f('unlocksToday', {
                    'count': '${app.unlocksLeftToday}'
                  })}',
              style: Typo.statLabel,
            ),
          ] else
            _Unavailable(text: l.t(credits == 0 ? 'unlockNoCredits' : 'unlockNoToday')),
        ],
      ),
    );
  }
}

class _Credits extends StatelessWidget {
  const _Credits({required this.count});

  static const _perRow = 5;

  final int count;

  @override
  Widget build(BuildContext context) {
    Widget pip(int index) => Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < count ? Palette.danger : Colors.transparent,
            border: Border.all(color: Palette.danger.withOpacity(index < count ? 1 : 0.35)),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var start = 0; start < Wallet.cap; start += _perRow) ...[
          if (start > 0) const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = start; i < start + _perRow; i++) ...[
                if (i > start) const SizedBox(width: 3),
                pip(i),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: Palette.surfaceLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock, size: 16, color: Palette.textMuted),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: Typo.small)),
        ],
      ),
    );
  }
}

class _HoldToUnlock extends StatefulWidget {
  const _HoldToUnlock({required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  State<_HoldToUnlock> createState() => _HoldToUnlockState();
}

class _HoldToUnlockState extends State<_HoldToUnlock> with SingleTickerProviderStateMixin {
  static const _steps = 4;

  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
    reverseDuration: const Duration(milliseconds: 320),
  )
    ..addListener(_onProgress)
    ..addStatusListener(_onStatus);
  int _ticks = 0;
  bool _done = false;
  bool _nudge = false;
  Timer? _nudgeTimer;

  void _onProgress() {
    if (_hold.status != AnimationStatus.forward) return;
    final step = (_hold.value * _steps).floor();
    if (step > _ticks && step < _steps) {
      _ticks = step;
      Haptics.selection();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _done) return;
    _done = true;
    Haptics.heavy();
    widget.onConfirmed();
  }

  void _down() {
    if (_done) return;
    _ticks = 0;
    _nudgeTimer?.cancel();
    Haptics.light();
    if (_nudge) setState(() => _nudge = false);
    _hold.forward();
  }

  void _up() {
    if (_done || _hold.status == AnimationStatus.completed) return;
    _hold.reverse();
    setState(() => _nudge = true);
    _nudgeTimer?.cancel();
    _nudgeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _nudge = false);
    });
  }

  @override
  void dispose() {
    _nudgeTimer?.cancel();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = l.t(_nudge ? 'keepHolding' : 'holdToUnlock');
    return Semantics(
      button: true,
      label: l.t('holdToUnlock'),
      onLongPress: _done ? null : widget.onConfirmed,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            final fill = Curves.easeInOut.transform(_hold.value);
            return Container(
              height: 54,
              decoration: BoxDecoration(
                color: Palette.danger.withOpacity(0.06),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: Palette.danger.withOpacity(0.45 + 0.45 * fill)),
                boxShadow: fill > 0
                    ? [BoxShadow(color: Palette.danger.withOpacity(0.25 * fill), blurRadius: 18 * fill)]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md - 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: fill,
                        heightFactor: 1,
                        child: ColoredBox(color: Palette.danger.withOpacity(0.24)),
                      ),
                    ),
                    if (fill > 0 && fill < 1)
                      Align(
                        alignment: AlignmentDirectional(fill * 2 - 1, 0),
                        child: Container(
                          width: 2,
                          decoration: const BoxDecoration(
                            color: Palette.danger,
                            boxShadow: [BoxShadow(color: Palette.danger, blurRadius: 10, spreadRadius: 1)],
                          ),
                        ),
                      ),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_open, size: 18, color: Palette.danger),
                          const SizedBox(width: Space.sm),
                          AnimatedSwitcher(
                            duration: Motion.fast,
                            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                            child: Caps(
                              label,
                              key: ValueKey(label),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Palette.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const _grayscale =
    ColorFilter.matrix([0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 0.7, 0]);
