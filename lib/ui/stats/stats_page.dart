import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/insights.dart';
import '../../data/models.dart';
import '../../state/scope.dart';
import '../motion/effects.dart';
import '../motion/reveal.dart';
import '../widgets/app_icon.dart';
import '../widgets/kit.dart';
import 'charts.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final insights = app.insights;
        final goal = app.preferences.dailyGoalMinutes * 60;
        final week = insights.weekSeconds;
        final previous = insights.previousWeekSeconds;
        final delta = previous == 0 ? null : ((week - previous) * 100 / previous).round();
        final pushUpsReached = app.pushUpsToday >= app.preferences.pushUpGoal;
        var order = 0;
        Widget staged(Widget child) => Reveal(index: order++, child: child);
        final best = insights.bestHour;
        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xxl),
          children: [
            staged(
              PageHeader(
                eyebrow: l.t('performance'),
                title: l.t('statsTitle'),
                trailing: Container(
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    color: Palette.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: const Icon(Icons.bar_chart, color: Palette.primary, size: 28),
                ),
              ),
            ),
            const SizedBox(height: Space.xl),
            staged(_TodayCard(seconds: insights.todaySeconds, goal: goal, insights: insights)),
            const SizedBox(height: Space.md),
            staged(
              _StatRow(
                first: _StatCard(
                  title: l.t('streakLabel'),
                  value: insights.currentStreak,
                  format: (value) => '$value',
                  icon: Icons.local_fire_department,
                  color: insights.focusedToday ? Palette.primary : Colors.white,
                  footer: l.f('bestStreak', {'count': '${insights.bestStreak}'}),
                ),
                second: _StatCard(
                  title: l.t('thisWeek'),
                  value: week,
                  format: (value) => Fmt.duration(l, value),
                  footer: delta == null
                      ? l.t('firstWeek')
                      : l.f(delta >= 0 ? 'weekUp' : 'weekDown', {'percent': '${delta.abs()}'}),
                  footerColor: delta == null ? null : (delta >= 0 ? Palette.success : Palette.danger),
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            staged(
              _StatRow(
                first: _StatCard(
                  title: l.t('completedLabel'),
                  value: insights.completedCount,
                  format: (value) => '$value',
                  footer: l.f('completionRate', {'percent': '${insights.completionRate}'}),
                ),
                second: _StatCard(
                  title: l.t('creditsLabel'),
                  value: app.wallet.available,
                  format: (value) => '$value',
                  color: Palette.success,
                  footer: l.f('unlocksToday', {'count': '${app.unlocksLeftToday}'}),
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            staged(
              _StatCard(
                title: l.t('pushUpsToday'),
                value: app.pushUpsToday,
                format: (value) => '$value/${app.preferences.pushUpGoal}',
                icon: Icons.fitness_center,
                color: pushUpsReached ? Palette.success : Palette.primary,
                footer: l.f('pushUpsTotal', {'count': '${app.pushUps.total}'}),
                progress: app.preferences.pushUpGoal == 0 ? 0 : app.pushUpsToday / app.preferences.pushUpGoal,
              ),
            ),
            const SizedBox(height: Space.xxl),
            staged(SectionTitle(l.t('thisWeek'))),
            const SizedBox(height: Space.lg),
            staged(WeekChart(days: insights.lastDays(7))),
            const SizedBox(height: Space.xxl),
            staged(SectionTitle(l.t('patterns'), trailing: _Faint(l.f('lastDays', {'count': '30'})))),
            const SizedBox(height: Space.md),
            staged(
              Row(
                children: [
                  Expanded(
                    child: _Pattern(
                      icon: Icons.wb_twilight,
                      label: l.t('bestHour'),
                      value: best == null ? '—' : Fmt.hour(context, best),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _Pattern(
                      icon: Icons.timelapse,
                      label: l.t('averageSession'),
                      value: insights.averageSeconds == 0 ? '—' : Fmt.duration(l, insights.averageSeconds),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _Pattern(
                      icon: Icons.emoji_events_outlined,
                      label: l.t('longestSession'),
                      value: insights.longestSeconds == 0 ? '—' : Fmt.duration(l, insights.longestSeconds),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xxl),
            SectionTitle(l.t('focusMap')),
            const SizedBox(height: Space.lg),
            FocusHeatmap(insights: insights),
            const SizedBox(height: Space.xxl),
            SectionTitle(
              l.t('distractions'),
              trailing: _Faint(l.f('distractionsTotal', {'count': '${app.lifetime.attempts}'})),
            ),
            const SizedBox(height: Space.md),
            _Distractions(entries: insights.topApps(7)),
            const SizedBox(height: Space.xxl),
            SectionTitle(l.t('recentSessions')),
            const SizedBox(height: Space.md),
            if (app.sessions.isEmpty)
              EmptyNote(l.t('noSessions'))
            else
              for (final session in app.sessions.take(12)) _SessionTile(session: session),
          ],
        );
      },
    );
  }
}

class _Faint extends StatelessWidget {
  const _Faint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Caps(
      text,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Palette.textFaint),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.seconds, required this.goal, required this.insights});

  final int seconds;
  final int goal;
  final Insights insights;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final percent = Fmt.percent(seconds, goal);
    final reached = goal > 0 && seconds >= goal;
    return CardBox(
      radius: Radii.lg,
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Caps(l.t('focusedToday'), style: Typo.statLabel)),
              AnimatedContainer(
                duration: Motion.medium,
                padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: Space.xs),
                decoration: BoxDecoration(
                  color: (reached ? Palette.success : Palette.primary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Caps(
                  l.f(reached ? 'goalDone' : 'ofGoal', {'percent': '$percent'}),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: reached ? Palette.success : Palette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          CountUp(
            value: seconds,
            builder: (context, value) => Text(
              Fmt.duration(l, value.round()),
              style: Typo.numeral.copyWith(fontSize: 40, color: Palette.primary, letterSpacing: -1, height: 1.1),
            ),
          ),
          const SizedBox(height: Space.lg),
          DayTimeline(spans: insights.todaySpans, now: insights.now),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          const SizedBox(width: Space.md),
          Expanded(child: second),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.format,
    this.color = Colors.white,
    this.icon,
    this.footer,
    this.footerColor,
    this.progress,
  });

  final String title;
  final int value;
  final String Function(int value) format;
  final Color color;
  final IconData? icon;
  final String? footer;
  final Color? footerColor;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Caps(title, style: Typo.statLabel)),
              if (icon != null) Icon(icon, size: 14, color: color == Colors.white ? Palette.textMuted : color),
            ],
          ),
          const SizedBox(height: Space.xs + 2),
          CountUp(
            value: value,
            builder: (context, current) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(format(current.round()), maxLines: 1, style: Typo.statValue.copyWith(color: color)),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: Space.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Replay(
                builder: (context, t) => LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0) * t,
                  minHeight: 3,
                  color: color,
                  backgroundColor: Palette.surfaceLight,
                ),
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: Space.xs + 2),
            Caps(
              footer!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: footerColor ?? Palette.textFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pattern extends StatelessWidget {
  const _Pattern({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Palette.primary),
          const SizedBox(height: Space.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, maxLines: 1, style: Typo.numeral.copyWith(fontSize: 17)),
          ),
          const SizedBox(height: 2),
          Caps(label, maxLines: 2, style: Typo.statLabel.copyWith(fontSize: 8)),
        ],
      ),
    );
  }
}

class _Distractions extends StatelessWidget {
  const _Distractions({required this.entries});

  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (entries.isEmpty) return EmptyNote(l.t('noDistractions'));
    final peak = entries.first.value;
    return FutureBuilder<Map<String, String>>(
      future: AppLabelCache.load(entries.map((entry) => entry.key).toList()),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? const {};
        return Column(
          children: [
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
                  child: Row(
                    children: [
                      AppIcon(entries[i].key, size: 32, label: labels[entries[i].key]),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labels[entries[i].key] ?? entries[i].key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Typo.strong,
                            ),
                            const SizedBox(height: Space.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: Replay(
                                duration: Duration(milliseconds: 700 + i * 120),
                                builder: (context, t) => LinearProgressIndicator(
                                  value: entries[i].value / peak * t,
                                  minHeight: 3,
                                  color: Palette.primary,
                                  backgroundColor: Palette.surfaceLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Text(
                        '${entries[i].value}',
                        style: Typo.numeral.copyWith(fontSize: 16, color: Palette.primary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, color, outcome) = switch (session.outcome) {
      SessionOutcome.completed => (Icons.check_circle, Palette.success, 'outcomeCompleted'),
      SessionOutcome.broken => (Icons.cancel, Palette.danger, 'outcomeBroken'),
      SessionOutcome.interrupted => (Icons.pause_circle, Palette.warning, 'outcomeInterrupted'),
    };
    final when = '${Fmt.day(l, session.startedAt, DateTime.now())}  ${Fmt.time(context, session.startedAt)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CardBox(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Space.xs + 2),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Fmt.duration(l, session.focusedSeconds), style: Typo.strong),
                  const SizedBox(height: 2),
                  Text(
                    session.intention == null ? '${l.t(outcome)} · $when' : '${session.intention} · $when',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Palette.textMuted),
                  ),
                ],
              ),
            ),
            if (session.attempts > 0) ...[
              const SizedBox(width: Space.sm),
              const Icon(Icons.block, size: 12, color: Palette.textMuted),
              const SizedBox(width: 2),
              Text('${session.attempts}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Palette.textMuted)),
            ],
            if (session.bonus) ...[
              const SizedBox(width: Space.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: Space.xs),
                decoration: BoxDecoration(
                  color: Palette.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Caps(
                  l.t('bonusCredit'),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Palette.success),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
