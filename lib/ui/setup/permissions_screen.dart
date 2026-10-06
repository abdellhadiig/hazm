import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../platform/blocker.dart';
import '../../state/guard_controller.dart';
import '../../state/scope.dart';
import '../motion/reveal.dart';
import '../widgets/dialogs.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';
import 'enable_blocking.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, this.firstRun = false, this.onDone});

  final bool firstRun;
  final VoidCallback? onDone;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  late final GuardController _guard = context.guard;
  bool? _dndBefore;

  @override
  void initState() {
    super.initState();
    _guard.addListener(_onGuard);
    _guard.refresh();
  }

  @override
  void dispose() {
    _guard
      ..removeListener(_onGuard)
      ..unwatch();
    super.dispose();
  }

  void _onGuard() {
    if (!_guard.loaded || !mounted) return;
    final granted = _guard.status.dndAccess;
    final app = context.app;
    if (_dndBefore == false && granted && !app.preferences.dnd) {
      app.updatePreferences(app.preferences.copyWith(dnd: true));
    }
    _dndBefore = granted;
  }

  Future<void> _notifications() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) await Blocker.openNotificationSettings();
    await _guard.refresh();
  }

  Future<void> _battery() async {
    _guard.watch(const Duration(minutes: 1));
    await Blocker.requestBatteryExemption();
  }

  Future<void> _autostart() async {
    if (!await Blocker.openAutostart()) await Blocker.openAppDetails();
  }

  Future<void> _test() async {
    final shown = await Blocker.testGuard();
    if (shown || !mounted) return;
    showToast(context, context.t('testFailed'), icon: Icons.shield_outlined, color: Palette.warning);
  }

  Future<void> _dnd() async {
    _guard.watch(const Duration(minutes: 1));
    await Blocker.openDndSettings();
  }

  void _finish() {
    final done = widget.onDone;
    if (done != null) {
      done();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: _guard,
      builder: (context, _) {
        final status = _guard.status;
        final ready = _guard.ready;
        final accessibility = !Blocker.available || (ready && _guard.running)
            ? PermissionState.on
            : ready
                ? PermissionState.warning
                : PermissionState.off;
        final tiles = <Widget>[
          PermissionTile(
            icon: Icons.accessibility_new,
            title: l.t('accessibility'),
            description: l.t(accessibility == PermissionState.warning ? 'notRunningDesc' : 'accessibilityDesc'),
            badge: l.t('required'),
            state: accessibility,
            onAction: () => ensureBlocking(context, restart: accessibility == PermissionState.warning),
            onTest: Blocker.available ? _test : null,
          ),
          PermissionTile(
            icon: Icons.notifications_active,
            title: l.t('notificationsTitle'),
            description: l.t('notificationsDesc'),
            badge: l.t('recommended'),
            state: status.notifications ? PermissionState.on : PermissionState.off,
            onAction: _notifications,
          ),
          PermissionTile(
            icon: Icons.battery_charging_full,
            title: l.t('batteryTitle'),
            description: l.t('batteryDesc'),
            badge: l.t('recommended'),
            state: status.battery ? PermissionState.on : PermissionState.off,
            action: l.t('allow'),
            onAction: _battery,
          ),
          if (status.autostart)
            PermissionTile(
              icon: Icons.restart_alt,
              title: l.t('autostartTitle'),
              description: l.t('autostartDesc'),
              state: PermissionState.info,
              action: l.t('open'),
              onAction: _autostart,
            ),
          PermissionTile(
            icon: Icons.do_not_disturb_on,
            title: l.t('dnd'),
            description: l.t('dndDesc'),
            badge: l.t('optional'),
            state: status.dndAccess ? PermissionState.on : PermissionState.off,
            onAction: _dnd,
          ),
        ];
        final done = [ready, status.notifications, status.battery].where((value) => value).length;
        return Scaffold(
          backgroundColor: Palette.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Reveal(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Space.md),
                          decoration: BoxDecoration(color: Palette.primary.withOpacity(0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.shield, color: Palette.primary, size: 40),
                        ),
                        const Spacer(),
                        if (widget.firstRun)
                          const _LanguageToggle()
                        else
                          IconSquare(
                            icon: Icons.close,
                            tooltip: l.t('close'),
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  Reveal(
                    index: 1,
                    child: Caps(
                      l.t('permissions'),
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Reveal(index: 2, child: Text(l.t('permissionsDesc'), style: Typo.body)),
                  const SizedBox(height: Space.lg),
                  Reveal(index: 3, child: _Meter(done: done, total: 3)),
                  const SizedBox(height: Space.lg),
                  Expanded(
                    child: ListView(
                      children: [
                        for (var i = 0; i < tiles.length; i++) Reveal(index: 4 + i, child: tiles[i]),
                        const SizedBox(height: Space.sm),
                        Reveal(
                          index: 4 + tiles.length,
                          child: NoticeCard(
                            icon: Icons.verified_user,
                            color: Palette.success,
                            title: l.t('safetyTitle'),
                            body: l.t('safetyBody'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(animation), child: child),
                    ),
                    child: ready
                        ? BlockButton(
                            key: const ValueKey('ready'),
                            label: l.t(widget.firstRun ? 'continue' : 'done'),
                            icon: Icons.arrow_forward,
                            onTap: _finish,
                          )
                        : BlockButton(
                            key: const ValueKey('later'),
                            label: l.t(widget.firstRun ? 'skipForNow' : 'notNow'),
                            tone: BlockTone.secondary,
                            onTap: _finish,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: Space.xs),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(color: Palette.surfaceLight, borderRadius: BorderRadius.circular(2)),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedFractionallySizedBox(
                  duration: Motion.slow,
                  curve: Motion.emphasized,
                  widthFactor: i < done ? 1 : 0,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: done == total ? Palette.success : Palette.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: Space.md),
        Text(
          '$done/$total',
          textDirection: TextDirection.ltr,
          style: Typo.numeral.copyWith(fontSize: 12, color: done == total ? Palette.success : Palette.textMuted),
        ),
        const SizedBox(width: Space.xs),
        Caps(l.t('readyLabel'), style: Typo.eyebrow.copyWith(fontSize: 9)),
      ],
    );
  }
}

enum PermissionState { off, warning, on, info }

class PermissionTile extends StatelessWidget {
  const PermissionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.state,
    required this.onAction,
    this.badge,
    this.action,
    this.onTest,
  });

  final IconData icon;
  final String title;
  final String description;
  final PermissionState state;
  final VoidCallback onAction;
  final String? badge;
  final String? action;
  final VoidCallback? onTest;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final on = state == PermissionState.on;
    final warning = state == PermissionState.warning;
    final tint = on
        ? Palette.success
        : warning
            ? Palette.warning
            : Palette.primary;
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.emphasized,
      margin: const EdgeInsets.only(bottom: Space.sm + 2),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: on
              ? Palette.success.withOpacity(0.3)
              : warning
                  ? Palette.warning.withOpacity(0.45)
                  : Palette.divider,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: Motion.medium,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: on ? Palette.success.withOpacity(0.12) : Palette.surfaceLight,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(
                on ? Icons.check : (warning ? Icons.priority_high : icon),
                key: ValueKey(state),
                color: tint,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Caps(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: on ? Palette.success : Colors.white,
                      ),
                    ),
                    if (badge != null && state == PermissionState.off)
                      StatusPill(label: badge!, color: Palette.textMuted),
                  ],
                ),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 10, color: Palette.textMuted, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          AnimatedSwitcher(
            duration: Motion.medium,
            switchInCurve: Motion.emphasized,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(animation), child: child),
            ),
            child: on
                ? (onTest == null
                    ? StatusPill(key: const ValueKey('on'), label: l.t('granted'), color: Palette.success, filled: true)
                    : Pressable(
                        key: const ValueKey('test'),
                        onTap: onTest,
                        scale: 0.92,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                          decoration: BoxDecoration(
                            color: Palette.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(color: Palette.success.withOpacity(0.5)),
                          ),
                          child: Caps(
                            l.t('testGuard'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Palette.success,
                            ),
                          ),
                        ),
                      ))
                : Pressable(
                    key: ValueKey(state),
                    onTap: onAction,
                    scale: 0.92,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                      decoration: BoxDecoration(
                        color: state == PermissionState.info ? Colors.transparent : tint,
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border: Border.all(color: state == PermissionState.info ? Palette.divider : tint),
                      ),
                      child: Caps(
                        action ?? l.t(warning ? 'fix' : 'grant'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: state == PermissionState.info ? Palette.textSecondary : Colors.black,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final current = app.preferences.language;
    return Container(
      padding: const EdgeInsets.all(Space.xs),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: Palette.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (code, label) in const [('en', 'English'), ('ar', 'العربية')])
            Pressable(
              onTap: () {
                if (code != current) app.updatePreferences(app.preferences.copyWith(language: code));
              },
              scale: 0.95,
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                decoration: BoxDecoration(
                  color: code == current ? Palette.primary.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: code == current ? Palette.primary : Palette.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
