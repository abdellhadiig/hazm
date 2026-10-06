import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../platform/blocker.dart';
import '../../state/guard_controller.dart';
import '../../state/scope.dart';
import '../motion/reveal.dart';
import '../setup/enable_blocking.dart';
import '../setup/permissions_screen.dart';
import '../widgets/dialogs.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';
import '../widgets/sheet.dart';
import 'allowed_apps_screen.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showHazmSheet<void>(
    context,
    title: (l) => l.t('settingsTitle'),
    builder: (_) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final GuardController _guard = context.guard;

  @override
  void initState() {
    super.initState();
    _guard.refresh();
  }

  @override
  void dispose() {
    _guard.unwatch();
    super.dispose();
  }

  BlockerStatus get _status => _guard.status;

  Future<void> _refresh() => _guard.refresh();

  void _update(Preferences Function(Preferences current) change) {
    final app = context.app;
    app.updatePreferences(change(app.preferences));
  }

  void _toggleUpdates(bool value) {
    _update((p) => p.copyWith(updates: value));
    if (value) context.app.checkForUpdates();
  }

  Future<void> _toggleDnd(bool value) async {
    if (value && Blocker.available && !_status.dndAccess) {
      final l = context.l10n;
      final open = await showConfirm(
        context,
        icon: Icons.do_not_disturb_on_outlined,
        title: l.t('dndAccessTitle'),
        message: l.t('dndAccessBody'),
        action: l.t('openSettings'),
      );
      if (open) {
        _guard.watch(const Duration(minutes: 1));
        await Blocker.openDndSettings();
      }
      return;
    }
    _update((p) => p.copyWith(dnd: value));
  }

  Future<void> _enableNotifications() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) await Blocker.openNotificationSettings();
    await _refresh();
  }

  Future<void> _reset() async {
    final l = context.l10n;
    final app = context.app;
    final session = context.session;
    final confirmed = await showConfirm(
      context,
      icon: Icons.warning_amber,
      title: l.t('resetConfirm'),
      message: l.t('resetWarning'),
      action: l.t('reset'),
      danger: true,
    );
    if (!confirmed) return;
    if (session.active) await session.cancel();
    await app.resetAll();
    if (!mounted) return;
    showToast(context, l.t('resetDone'), icon: Icons.restart_alt);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final session = context.session;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([app, session, _guard]),
      builder: (context, _) {
        final p = app.preferences;
        final locked = session.active;
        var order = 0;
        Widget staged(Widget child) => Reveal(index: order++, offset: const Offset(0, 12), child: child);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            staged(_GuardCard(guard: _guard)),
            const SizedBox(height: Space.lg),
            if (locked) ...[
              CardBox(
                color: Palette.primary.withOpacity(0.06),
                border: Palette.primary.withOpacity(0.25),
                radius: Radii.lg,
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock, size: 18, color: Palette.primary),
                    const SizedBox(width: Space.sm),
                    Expanded(
                        child: Text(l.t('settingsLocked'), style: Typo.small.copyWith(color: Palette.textSecondary))),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
            ],
            staged(
              _CreditInfo(
                credits: app.wallet.available,
                left: app.unlocksLeftToday,
                limit: p.dailyUnlockLimit,
                threshold: p.bonusThresholdMinutes,
              ),
            ),
            const SizedBox(height: Space.xl),
            staged(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(l.t('language')),
                  Row(
                    children: [
                      Expanded(
                        child: _LanguageOption(
                          label: 'English',
                          flag: '🇬🇧',
                          selected: p.language == 'en',
                          onTap: () => _update((p) => p.copyWith(language: 'en')),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: _LanguageOption(
                          label: 'العربية',
                          flag: '🇸🇦',
                          selected: p.language == 'ar',
                          onTap: () => _update((p) => p.copyWith(language: 'ar')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            staged(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(l.t('dailyGoal')),
                  _SliderCard(
                    value: p.dailyGoalMinutes,
                    min: 15,
                    max: 480,
                    step: 15,
                    label: Fmt.minutes(l, p.dailyGoalMinutes),
                    onChanged: (value) => _update((p) => p.copyWith(dailyGoalMinutes: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            staged(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(l.t('creditThreshold')),
                  ChoiceChips<int>(
                    values: const [60, 90, 120],
                    selected: p.bonusThresholdMinutes,
                    labelOf: (value) => Fmt.minutes(l, value),
                    onChanged: locked ? null : (value) => _update((p) => p.copyWith(bonusThresholdMinutes: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            _Label(l.t('dailyUnlocks')),
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
              child: Row(
                children: [
                  const Icon(Icons.lock_open, size: 18, color: Palette.textMuted),
                  const Spacer(),
                  NumberStepper(
                    value: p.dailyUnlockLimit,
                    min: 1,
                    max: 5,
                    onChanged: locked ? null : (value) => _update((p) => p.copyWith(dailyUnlockLimit: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            _Label(l.t('sectionBlocking')),
            _RowCard(
              icon: Icons.apps,
              title: l.t('allowedApps'),
              subtitle: l.t(locked ? 'allowedAppsLocked' : 'allowedAppsSubtitle'),
              trailing: const Icon(Icons.chevron_right, color: Palette.textMuted),
              onTap: locked
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AllowedAppsScreen()),
                      ),
            ),
            const SizedBox(height: Space.sm),
            _RowCard(
              icon: Icons.do_not_disturb_on_outlined,
              title: l.t('dndDuring'),
              subtitle: l.t('dndDuringSubtitle'),
              trailing: Switch(value: p.dnd && (_status.dndAccess || !Blocker.available), onChanged: _toggleDnd),
            ),
            const SizedBox(height: Space.xl),
            _Label(l.t('pushUpGoal')),
            _SliderCard(
              value: p.pushUpGoal,
              min: 5,
              max: 100,
              step: 5,
              label: '${p.pushUpGoal}',
              onChanged: (value) => _update((p) => p.copyWith(pushUpGoal: value)),
            ),
            const SizedBox(height: Space.xl),
            _Label(l.t('pushUpReward')),
            ChoiceChips<int>(
              values: const [15, 30, 45, 60],
              selected: p.pushUpSeconds,
              labelOf: (value) => '$value${l.t('unitS')}',
              onChanged: locked ? null : (value) => _update((p) => p.copyWith(pushUpSeconds: value)),
            ),
            const SizedBox(height: Space.xl),
            _Label(l.t('sectionGeneral')),
            _RowCard(
              icon: Icons.vibration,
              title: l.t('haptics'),
              trailing: Switch(value: p.haptics, onChanged: (value) => _update((p) => p.copyWith(haptics: value))),
            ),
            const SizedBox(height: Space.sm),
            _RowCard(
              icon: Icons.system_update_alt,
              title: l.t('checkUpdates'),
              subtitle: l.t('checkUpdatesSubtitle'),
              trailing: Switch(value: p.updates, onChanged: _toggleUpdates),
            ),
            const SizedBox(height: Space.xl),
            _Label(l.t('permissions')),
            PermissionTile(
              icon: Icons.notifications_active,
              title: l.t('notificationsTitle'),
              description: l.t('notificationsDesc'),
              state: _status.notifications ? PermissionState.on : PermissionState.off,
              onAction: _enableNotifications,
            ),
            PermissionTile(
              icon: Icons.battery_charging_full,
              title: l.t('batteryTitle'),
              description: l.t('batteryDesc'),
              state: _status.battery ? PermissionState.on : PermissionState.off,
              action: l.t('allow'),
              onAction: () {
                _guard.watch(const Duration(minutes: 1));
                Blocker.requestBatteryExemption();
              },
            ),
            _RowCard(
              icon: Icons.tune,
              title: l.t('allPermissions'),
              subtitle: l.t('allPermissionsSubtitle'),
              trailing: const Icon(Icons.chevron_right, color: Palette.textMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PermissionsScreen()),
              ),
            ),
            const SizedBox(height: Space.md),
            NoticeCard(
              icon: Icons.verified_user,
              color: Palette.success,
              title: l.t('safetyTitle'),
              body: l.t('safetyBody'),
            ),
            const SizedBox(height: Space.xxl),
            Container(height: 1, color: Palette.divider),
            const SizedBox(height: Space.lg),
            BlockButton(label: l.t('resetAllData'), tone: BlockTone.danger, onTap: _reset),
            const SizedBox(height: Space.lg),
            Center(
              child: Text(
                [
                  'HAZM',
                  if (app.version != null) app.version!,
                  '· ${l.t('aboutFooter')}',
                ].join(' '),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Palette.textFaint),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Caps(text, style: Typo.eyebrow),
    );
  }
}

class _CreditInfo extends StatelessWidget {
  const _CreditInfo({required this.credits, required this.left, required this.limit, required this.threshold});

  final int credits;
  final int left;
  final int limit;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const rule = TextStyle(fontSize: 12, color: Palette.textSecondary, height: 1.6);
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: Palette.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Palette.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Palette.primary),
              const SizedBox(width: Space.sm),
              Caps(
                l.t('creditSystem'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.primary),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(l.f('creditRule1', {'time': Fmt.minutes(l, threshold)}), style: rule),
          const SizedBox(height: Space.xs),
          Text(l.f('creditRule2', {'count': '$limit'}), style: rule),
          const SizedBox(height: Space.xs),
          Text(l.f('creditRule3', {'max': '${Wallet.cap}'}), style: rule),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
                decoration: BoxDecoration(
                  color: Palette.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: Palette.primary.withOpacity(0.4)),
                ),
                child: Caps(
                  l.f('creditsPill', {'count': '$credits'}),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Palette.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
                decoration: BoxDecoration(
                  color: Palette.surfaceLight,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Caps(
                  l.f('todayPill', {'left': '$left', 'limit': '$limit'}),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Palette.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.label, required this.flag, required this.selected, required this.onTap});

  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        if (!selected) onTap();
      },
      scale: 0.96,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.md),
        decoration: BoxDecoration(
          color: selected ? Palette.primary.withOpacity(0.12) : Palette.surfaceLight,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: selected ? Palette.primary : Palette.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: Space.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Palette.primary : Palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.sm, Space.lg, Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) ~/ step,
              onChanged: (raw) {
                final next = raw.round();
                if (next != value) onChanged(next);
              },
            ),
          ),
          ValueBadge(label, width: 64),
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.md, Space.md, Space.sm, Space.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: Palette.surfaceLight, borderRadius: BorderRadius.circular(Radii.sm)),
            child: Icon(icon, size: 18, color: Palette.primary),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Typo.strong),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(fontSize: 10, color: Palette.textMuted, height: 1.4)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
        ],
      ),
    );
  }
}

class _GuardCard extends StatelessWidget {
  const _GuardCard({required this.guard});

  final GuardController guard;

  Future<void> _test(BuildContext context) async {
    final shown = await Blocker.testGuard();
    if (shown || !context.mounted) return;
    showToast(context, context.t('testFailed'), icon: Icons.shield_outlined, color: Palette.warning);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ready = guard.ready;
    final running = guard.running;
    final (color, icon, title, body) = running
        ? (Palette.success, Icons.shield, 'guardActive', 'guardActiveBody')
        : ready
            ? (Palette.warning, Icons.shield_outlined, 'guardStalled', 'notRunningDesc')
            : (Palette.danger, Icons.gpp_bad_outlined, 'guardDisabled', 'guardDisabledBody');
    return AnimatedContainer(
      duration: Motion.medium,
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(Radii.sm)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Caps(l.t(title),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: color)),
                const SizedBox(height: 2),
                Text(l.t(body), style: const TextStyle(fontSize: 10, color: Palette.textMuted, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          if (running)
            TintPill(label: l.t('testGuard'), color: color, onTap: () => _test(context))
          else
            TintPill(
              label: l.t(ready ? 'fix' : 'turnOn'),
              color: color,
              onTap: () => ensureBlocking(context, restart: ready),
            ),
        ],
      ),
    );
  }
}
