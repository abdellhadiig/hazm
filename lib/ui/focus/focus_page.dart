import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../platform/blocker.dart';
import '../../state/scope.dart';
import '../motion/effects.dart';
import '../motion/reveal.dart';
import '../motion/transitions.dart';
import '../setup/enable_blocking.dart';
import '../widgets/dialogs.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';
import '../widgets/ticker.dart';
import 'big_clock.dart';
import 'duration_picker.dart';
import 'lock_button.dart';
import 'objective_sheet.dart';
import 'session_actions.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({super.key, required this.focusRequest, required this.onOpenSettings});

  final ValueNotifier<TaskItem?> focusRequest;
  final VoidCallback onOpenSettings;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  static const _quick = [25, 45, 60, 90];
  static const _sessionKey = ValueKey('session');
  static const _idleKey = ValueKey('idle');

  late int _minutes;
  Objective _objective = noObjective;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _minutes = context.app.preferences.selectedMinutes;
    widget.focusRequest.addListener(_applyRequest);
    _applyRequest();
  }

  @override
  void dispose() {
    widget.focusRequest.removeListener(_applyRequest);
    super.dispose();
  }

  void _applyRequest() {
    final task = widget.focusRequest.value;
    if (task == null) return;
    widget.focusRequest.value = null;
    setState(() => _objective = (text: task.title, taskId: task.id));
  }

  void _setMinutes(int minutes) {
    if (minutes == _minutes) return;
    setState(() => _minutes = minutes);
    final app = context.app;
    if (app.preferences.selectedMinutes != minutes) {
      app.updatePreferences(app.preferences.copyWith(selectedMinutes: minutes));
    }
  }

  Future<void> _pickDuration() async {
    final minutes = await showDurationPicker(context, _minutes);
    if (minutes != null && mounted) _setMinutes(minutes);
  }

  Future<void> _pickObjective() async {
    final result = await showObjectiveSheet(context, tasks: context.app.openTasks, current: _objective);
    if (result != null && mounted) setState(() => _objective = result);
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      if (Blocker.available) {
        final ready = await ensureBlocking(context);
        if (!ready || !mounted) return;
        if (await Permission.notification.isDenied) await Permission.notification.request();
      }
      if (!mounted) return;
      final started = await context.session.start(
        minutes: _minutes,
        taskId: _objective.taskId,
        intention: _objective.text,
      );
      if (!mounted) return;
      if (started) {
        setState(() => _objective = noObjective);
      } else {
        showToast(context, context.t('startFailed'), icon: Icons.error_outline, color: Palette.danger);
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _resume() async {
    await context.session.resume();
  }

  Future<void> _openUpdate(ReleaseInfo release) async {
    final opened = await Blocker.openUrl(release.download);
    if (!opened && mounted) {
      showToast(context, context.t('openFailed'), icon: Icons.error_outline, color: Palette.danger);
    }
  }

  Future<void> _extend() async {
    Haptics.medium();
    await context.session.extend(5);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final session = context.session;
    final guard = context.guard;
    return ListenableBuilder(
      listenable: Listenable.merge([app, session, guard]),
      builder: (context, _) => SecondTicker(
        enabled: session.active,
        read: () => session.active ? Fmt.ceilSeconds(session.paused ? session.pauseRemaining : session.remaining) : -1,
        builder: (context, value) => _layout(context, session.active ? value : null),
      ),
    );
  }

  Widget _layout(BuildContext context, int? seconds) {
    final l = context.l10n;
    final app = context.app;
    final session = context.session;
    final active = seconds != null;
    final paused = active && session.paused;
    final exposed = active && !paused && context.guard.exposed;
    final update = active ? null : app.update;
    final accent = paused ? Palette.warning : Palette.primary;
    final insights = app.insights;
    final goalSeconds = app.preferences.dailyGoalMinutes * 60;
    final progress =
        active ? session.progress : (goalSeconds <= 0 ? 0.0 : (insights.todaySeconds / goalSeconds).clamp(0.0, 1.0));
    final percent =
        active ? (session.progress * 100).round() : Fmt.percent(insights.todaySeconds, goalSeconds).clamp(0, 999);
    final progressCaption = l.t(active ? 'doneCaption' : 'goalCaption');
    final caption = paused
        ? l.t('breakRemaining')
        : active
            ? l.t('timeRemaining')
            : l.t(_minutes >= 60 ? 'durationSet' : 'minutesSelected');
    final spine = paused ? l.t('breakMode') : l.t(active ? 'sessionActive' : 'deepWorkMode');
    return Stack(
      children: [
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 80,
          width: 48,
          child: Reveal(
            offset: const Offset(0, 48),
            duration: Motion.long,
            child: _Spine(text: spine, color: accent),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 56, end: 20, top: Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Reveal(
                child: _Header(
                  number: app.lifetime.sessions + 1,
                  streak: insights.currentStreak,
                  hot: insights.focusedToday,
                  onOpenSettings: widget.onOpenSettings,
                ),
              ),
              const SizedBox(height: Space.lg),
              Reveal(
                index: 1,
                child: _CreditRow(
                  credits: app.wallet.available,
                  left: app.unlocksLeftToday,
                  limit: app.preferences.dailyUnlockLimit,
                ),
              ),
              AnimatedSize(
                duration: Motion.medium,
                curve: Motion.emphasized,
                alignment: AlignmentDirectional.topStart,
                child: exposed
                    ? Padding(
                        padding: const EdgeInsets.only(top: Space.md),
                        child: _GuardStrip(onTap: () => ensureBlocking(context, restart: true)),
                      )
                    : update != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: Space.md),
                            child: _UpdateStrip(
                              version: update.version,
                              onUpdate: () => _openUpdate(update),
                              onSkip: app.skipUpdate,
                            ),
                          )
                        : const SizedBox(width: double.infinity),
              ),
              Expanded(
                child: Reveal(
                  index: 2,
                  offset: const Offset(0, 28),
                  child: _Stage(
                    onTap: active ? null : _pickDuration,
                    semanticLabel: active ? null : l.t('changeDuration'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        BigClock(seconds: seconds ?? _minutes * 60, caption: caption, accent: accent),
                        const SizedBox(height: Space.lg),
                        AnimatedSwitcher(
                          duration: Motion.slow,
                          layoutBuilder: (current, previous) =>
                              stackLayout(current, previous, alignment: AlignmentDirectional.topEnd),
                          transitionBuilder: fadeThrough(active ? _sessionKey : _idleKey),
                          child: active
                              ? _SessionDetails(
                                  key: _sessionKey,
                                  paused: paused,
                                  onBreak: () => earnBreak(context),
                                  onExtend: _extend,
                                )
                              : _IdleDetails(
                                  key: _idleKey,
                                  values: _quick,
                                  minutes: _minutes,
                                  objective: _objective.text,
                                  onMinutes: _setMinutes,
                                  onObjective: _pickObjective,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Reveal(
                index: 3,
                child: _ProgressLine(
                  progress: progress,
                  value: Fmt.pct(l, percent),
                  caption: progressCaption,
                  live: active,
                ),
              ),
              const SizedBox(height: Space.md),
            ],
          ),
        ),
        PositionedDirectional(
          bottom: Space.lg,
          end: 20,
          child: Reveal(
            index: 4,
            offset: const Offset(0, 36),
            child: LockButton(
              mode: paused
                  ? LockMode.paused
                  : active
                      ? LockMode.locked
                      : LockMode.idle,
              onLock: _start,
              onResume: _resume,
              onLockedTap: () => showUnlockOptions(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _Spine extends StatelessWidget {
  const _Spine({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = ValueKey(text);
    return Center(
      child: RotatedBox(
        quarterTurns: rtl ? 3 : 1,
        child: AnimatedSwitcher(
          duration: Motion.long,
          transitionBuilder: fadeThrough(key, offset: const Offset(-0.12, 0)),
          child: Text(
            text,
            key: key,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: color, height: 1),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.number, required this.streak, required this.hot, required this.onOpenSettings});

  final int number;
  final int streak;
  final bool hot;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Caps('${l.t('session')} ${Fmt.two(number)}', style: Typo.eyebrow),
              const SizedBox(height: 2),
              const Text('HAZM', style: Typo.brand),
            ],
          ),
        ),
        if (streak > 0) ...[
          _StreakChip(days: streak, hot: hot),
          const SizedBox(width: Space.sm),
        ],
        IconSquare(icon: Icons.settings, tooltip: l.t('settings'), onTap: onOpenSettings),
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days, required this.hot});

  final int days;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = hot ? Palette.primary : Palette.textMuted;
    return Tooltip(
      message: l.f('streakTooltip', {'count': '$days'}),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        decoration: BoxDecoration(
          color: hot ? Palette.primary.withOpacity(0.1) : Palette.surfaceLight,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, size: 18, color: color),
            const SizedBox(width: Space.xs),
            Text('$days', style: Typo.numeral.copyWith(fontSize: 15, color: color)),
          ],
        ),
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credits, required this.left, required this.limit});

  final int credits;
  final int left;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        const Icon(Icons.lock_open, size: 16, color: Palette.primary),
        const SizedBox(width: Space.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
          decoration: BoxDecoration(
            color: Palette.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: Palette.primary.withOpacity(0.4)),
          ),
          child: Text(
            '$credits',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Palette.primary),
          ),
        ),
        const SizedBox(width: Space.sm),
        Flexible(
          child: Caps(
            l.t('creditsLabel'),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Palette.textMuted.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(width: Space.md),
        Container(width: 1, height: 14, color: Palette.divider),
        const SizedBox(width: Space.md),
        Text(
          '$left/$limit',
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Palette.textMuted),
        ),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Caps(
            l.t('todayLabel'),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Palette.textMuted.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuardStrip extends StatelessWidget {
  const _GuardStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.md, Space.sm + 2, Space.sm, Space.sm + 2),
        decoration: BoxDecoration(
          color: Palette.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: Palette.warning.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Breathing(
              builder: (context, value) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.warning,
                  boxShadow: [
                    BoxShadow(color: Palette.warning.withOpacity(0.25 + value * 0.5), blurRadius: 4 + value * 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Space.sm + 2),
            Expanded(
              child: Caps(
                l.t('guardOff'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: Palette.warning,
                ),
              ),
            ),
            Caps(
              l.t('fix'),
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _UpdateStrip extends StatelessWidget {
  const _UpdateStrip({required this.version, required this.onUpdate, required this.onSkip});

  final String version;
  final VoidCallback onUpdate;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.f('updateAvailable', {'version': version});
    const label = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5);
    return Pressable(
      onTap: onUpdate,
      scale: 0.98,
      semanticLabel: title,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.md, 2, 2, 2),
        decoration: BoxDecoration(
          color: Palette.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: Palette.primary.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.system_update_alt, size: 16, color: Palette.primary),
            const SizedBox(width: Space.sm + 2),
            Expanded(child: Caps(title, style: label.copyWith(color: Palette.primary))),
            Caps(l.t('update'), style: label.copyWith(color: Colors.white)),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white),
            IconButton(
              onPressed: onSkip,
              tooltip: l.t('skipUpdate'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16, color: Palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.child, this.onTap, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(child: CustomPaint(painter: _DiagonalPainter(rtl: rtl))),
            ),
            Align(
              alignment: Alignment.center,
              child: FittedBox(fit: BoxFit.scaleDown, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleDetails extends StatelessWidget {
  const _IdleDetails({
    super.key,
    required this.values,
    required this.minutes,
    required this.objective,
    required this.onMinutes,
    required this.onObjective,
  });

  final List<int> values;
  final int minutes;
  final String? objective;
  final ValueChanged<int> onMinutes;
  final VoidCallback onObjective;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _QuickDurations(values: values, selected: minutes, onSelect: onMinutes),
        const SizedBox(height: Space.sm),
        _ObjectiveButton(text: objective, onTap: onObjective),
      ],
    );
  }
}

class _QuickDurations extends StatelessWidget {
  const _QuickDurations({required this.values, required this.selected, required this.onSelect});

  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final value in values)
          Pressable(
            onTap: () => onSelect(value),
            scale: 0.9,
            semanticLabel: Fmt.minutes(l, value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: Space.sm),
              child: _QuickValue(minutes: value, selected: value == selected),
            ),
          ),
      ],
    );
  }
}

class _QuickValue extends StatelessWidget {
  const _QuickValue({required this.minutes, required this.selected});

  final int minutes;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hours = minutes >= 60;
    final amount = hours ? (minutes % 60 == 0 ? '${minutes ~/ 60}' : (minutes / 60).toStringAsFixed(1)) : '$minutes';
    final color = selected ? Palette.primary : Palette.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedDefaultTextStyle(
              duration: Motion.fast,
              style: Typo.numeral.copyWith(fontSize: 15, color: selected ? Colors.white : Palette.textSecondary),
              child: Text(amount, textDirection: TextDirection.ltr),
            ),
            const SizedBox(width: 2),
            Text(
              l.t(hours ? 'unitH' : 'unitM'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.emphasized,
          height: 2,
          width: selected ? 18 : 0,
          color: Palette.primary,
        ),
      ],
    );
  }
}

class _ObjectiveButton extends StatelessWidget {
  const _ObjectiveButton({required this.text, required this.onTap});

  final String? text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = text;
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value == null ? Icons.add : Icons.flag_outlined,
                size: 14, color: value == null ? Palette.textMuted : Palette.primary),
            const SizedBox(width: Space.xs + 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: value == null
                  ? Caps(
                      context.t('setObjective'),
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: Palette.textMuted),
                    )
                  : Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.item),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionDetails extends StatelessWidget {
  const _SessionDetails({super.key, required this.paused, required this.onBreak, required this.onExtend});

  final bool paused;
  final VoidCallback onBreak;
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.session;
    final intention = session.intention;
    final parts = [
      if (session.attempts > 0) l.f('metaBlocked', {'count': '${session.attempts}'}),
      l.f('metaEnds', {'time': Fmt.time(context, session.endsAt)}),
      if (session.snapshot?.dnd == true) l.t('metaDnd'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (intention != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_outlined, size: 14, color: Palette.primary),
              const SizedBox(width: Space.xs + 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: Text(intention, maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.item),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
        ],
        Caps(
          parts.join('  ·  '),
          style:
              const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Palette.textMuted),
        ),
        const SizedBox(height: Space.md),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!paused) ...[
              TintPill(
                label: l.t('optionPushUps'),
                icon: Icons.fitness_center,
                color: Palette.primary,
                onTap: onBreak,
              ),
              const SizedBox(width: Space.sm),
            ],
            TintPill(
              label: l.t('extendFive'),
              icon: Icons.add,
              color: Palette.textSecondary,
              onTap: session.canExtend ? onExtend : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress, required this.value, required this.caption, required this.live});

  final double progress;
  final String value;
  final String caption;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final angle = rtl ? 0.05 : -0.05;
    return SizedBox(
      height: 70,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                  duration: live ? Motion.fast : Motion.long,
                  curve: live ? Curves.linear : Motion.emphasized,
                  builder: (context, value, _) => Breathing(
                    enabled: live,
                    builder: (context, glow) => CustomPaint(
                      painter: _LinePainter(progress: value, glow: live ? glow : 0, angle: angle, rtl: rtl),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 38,
              start: 0,
              width: math.max(56.0, constraints.maxWidth - LockButton.width - Space.md),
              child: Transform.rotate(
                angle: angle,
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        textDirection: TextDirection.ltr,
                        style: Typo.numeral.copyWith(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                      ),
                      const SizedBox(width: Space.xs + 1),
                      Caps(
                        caption,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.progress, required this.glow, required this.angle, required this.rtl});

  final double progress;
  final double glow;
  final double angle;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 27.0;
    final half = size.width / 2;
    canvas
      ..save()
      ..translate(half, top)
      ..rotate(angle);
    final base = Paint()
      ..color = Palette.divider
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-half, 0), Offset(half, 0), base);
    if (progress > 0) {
      final start = rtl ? half : -half;
      final end = start + (rtl ? -1 : 1) * size.width * progress;
      final halo = Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final line = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(Offset(start, 0), Offset(end, 0), halo)
        ..drawLine(Offset(start, 0), Offset(end, 0), line);
      if (glow > 0) {
        canvas
          ..drawCircle(
            Offset(end, 0),
            6 + glow * 6,
            Paint()
              ..color = Palette.primary.withOpacity(0.18 + glow * 0.22)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          )
          ..drawCircle(Offset(end, 0), 3, Paint()..color = Colors.white);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.glow != glow ||
      oldDelegate.angle != angle ||
      oldDelegate.rtl != rtl;
}

class _DiagonalPainter extends CustomPainter {
  const _DiagonalPainter({required this.rtl});

  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.divider.withOpacity(0.4)
      ..strokeWidth = 1;
    if (rtl) {
      canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    } else {
      canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DiagonalPainter oldDelegate) => oldDelegate.rtl != rtl;
}
