import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/scope.dart';
import '../motion/effects.dart';
import '../motion/reveal.dart';
import '../widgets/dialogs.dart';
import '../widgets/kit.dart';

Future<void> presentResult(BuildContext context, SessionRecord record) async {
  final l = context.l10n;
  switch (record.outcome) {
    case SessionOutcome.completed:
      Haptics.heavy();
      await showHazmDialog<void>(
        context,
        dismissible: false,
        builder: (_) => _ResultCard(record: record, completed: true),
      );
    case SessionOutcome.interrupted:
      await showHazmDialog<void>(
        context,
        dismissible: false,
        builder: (_) => _ResultCard(record: record, completed: false),
      );
    case SessionOutcome.broken:
      showToast(context, l.f('endedEarly', {'time': Fmt.duration(l, record.focusedSeconds)}), icon: Icons.lock_open);
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.record, required this.completed});

  final SessionRecord record;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final app = context.app;
    final insights = app.insights;
    final accent = completed ? Palette.success : Palette.warning;
    final goal = app.preferences.dailyGoalMinutes * 60;
    final goalReached =
        completed && insights.todaySeconds >= goal && insights.todaySeconds - record.focusedSeconds < goal;
    final reason = switch (record.reason) {
      'service_off' => 'stoppedServiceOff',
      'clock' => 'stoppedClock',
      _ => 'stoppedOther',
    };
    final badges = [
      if (record.bonus) (Icons.star, l.t('bonusEarned'), Palette.success),
      if (record.capped) (Icons.star_border, l.f('creditsFull', {'max': '${Wallet.cap}'}), Palette.textSecondary),
      if (goalReached) (Icons.flag, l.t('goalReached'), Palette.primary),
      if (record.unguardedSeconds >= 60)
        (
          Icons.shield_outlined,
          l.f('unguardedNote', {'time': Fmt.duration(l, record.unguardedSeconds)}),
          Palette.warning
        ),
    ];
    var order = 0;
    Widget staged(Widget child) => Reveal(index: order++, delay: const Duration(milliseconds: 220), child: child);
    return DialogCard(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            builder: (context, value, _) => SizedBox.square(
              dimension: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (completed) Starburst(progress: value, color: Palette.primary, size: 132),
                  Transform.scale(
                    scale: Curves.easeOutBack.transform((value * 1.6).clamp(0.0, 1.0)),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(color: accent.withOpacity(0.14), shape: BoxShape.circle),
                      child: Center(
                        child: completed
                            ? DrawnCheck(
                                progress: Curves.easeOutCubic.transform(((value - 0.25) / 0.5).clamp(0.0, 1.0)),
                                size: 48,
                              )
                            : Icon(Icons.pause_rounded, color: accent, size: 40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          staged(
            Caps(
              l.t(completed ? 'sessionComplete' : 'sessionStopped'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white),
            ),
          ),
          const SizedBox(height: Space.md),
          staged(
            Column(
              children: [
                CountUp(
                  value: record.focusedSeconds,
                  duration: const Duration(milliseconds: 1400),
                  builder: (context, value) => Text(
                    Fmt.duration(l, value.round()),
                    textAlign: TextAlign.center,
                    style: Typo.numeral.copyWith(fontSize: 44, color: Palette.primary, letterSpacing: -1),
                  ),
                ),
                Caps(l.t('focusedLabel'), style: Typo.eyebrow.copyWith(color: Palette.textSecondary)),
              ],
            ),
          ),
          if (completed && record.intention != null) ...[
            const SizedBox(height: Space.md),
            staged(
              Text(
                record.intention!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Typo.body.copyWith(color: Colors.white),
              ),
            ),
          ],
          if (!completed) ...[
            const SizedBox(height: Space.md),
            staged(Text(l.t(reason), textAlign: TextAlign.center, style: Typo.body)),
          ],
          if (badges.isNotEmpty) ...[
            const SizedBox(height: Space.lg),
            staged(
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final (icon, text, color) in badges) _Badge(icon: icon, text: text, color: color),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.xl),
          staged(
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: l.t('todayLabel'),
                    value: insights.todaySeconds,
                    format: (value) => Fmt.duration(l, value),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _StatBox(
                    label: l.t('streakLabel'),
                    value: insights.currentStreak,
                    format: (value) => '$value',
                    color: Palette.primary,
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: _StatBox(label: l.t('blockedLabel'), value: record.attempts, format: (value) => '$value'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          staged(
            BlockButton(
              label: l.t(completed ? 'continue' : 'gotIt'),
              icon: Icons.arrow_forward,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: Space.xs + 2),
          Flexible(
            child: Caps(
              text,
              maxLines: 2,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.format, this.color = Colors.white});

  final String label;
  final int value;
  final String Function(int value) format;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.md),
      child: Column(
        children: [
          Caps(label, style: const TextStyle(fontSize: 10, letterSpacing: 1, color: Palette.textMuted)),
          const SizedBox(height: Space.xs),
          CountUp(
            value: value,
            builder: (context, current) => Text(
              format(current.round()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Typo.numeral.copyWith(fontSize: 18, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
