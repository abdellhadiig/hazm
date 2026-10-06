import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../platform/blocker.dart';
import '../../state/guard_controller.dart';
import '../../state/scope.dart';
import '../motion/effects.dart';
import '../motion/reveal.dart';
import '../widgets/kit.dart';
import '../widgets/sheet.dart';

Future<bool> ensureBlocking(BuildContext context, {bool restart = false}) async {
  if (!Blocker.available) return true;
  final guard = context.guard;
  final status = await guard.refresh();
  if (!context.mounted) return false;
  if (!restart && status.accessibility) return true;
  final result = await showHazmSheet<bool>(
    context,
    title: (l) => l.t(restart ? 'guardTitle' : 'blockingTitle'),
    scrollable: false,
    builder: (_) => EnableBlocking(restart: restart),
  );
  return result ?? (restart ? guard.running : guard.ready);
}

class EnableBlocking extends StatefulWidget {
  const EnableBlocking({super.key, this.restart = false});

  final bool restart;

  @override
  State<EnableBlocking> createState() => _EnableBlockingState();
}

class _EnableBlockingState extends State<EnableBlocking> {
  late final GuardController _guard = context.guard;
  bool _tried = false;
  bool _done = false;

  bool get _satisfied => widget.restart ? _guard.running : _guard.ready;

  @override
  void initState() {
    super.initState();
    _guard
      ..addListener(_changed)
      ..watch();
  }

  @override
  void dispose() {
    _guard
      ..removeListener(_changed)
      ..unwatch();
    super.dispose();
  }

  void _changed() {
    if (_done || !mounted) return;
    if (!_satisfied) {
      setState(() {});
      return;
    }
    Haptics.medium();
    setState(() => _done = true);
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _open() async {
    setState(() => _tried = true);
    _guard.watch();
    await Blocker.openAccessibilitySettings();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.medium,
      curve: Motion.emphasized,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Motion.medium,
        child: _done
            ? const Padding(
                key: ValueKey('done'),
                padding: EdgeInsets.all(Space.xl),
                child: _Success(),
              )
            : SheetLayout(
                key: const ValueKey('steps'),
                body: _body(context),
                footer: _footer(context),
              ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final status = _guard.status;
    final restart = widget.restart;
    final steps = restart
        ? const ['guardStep1', 'guardStep2', 'guardStep3']
        : const ['blockingStep1', 'blockingStep2', 'blockingStep3'];
    var index = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reveal(
          index: index++,
          child: Text(l.t(restart ? 'guardBody' : 'blockingBody'), style: Typo.body.copyWith(color: Colors.white)),
        ),
        const SizedBox(height: Space.xl),
        Reveal(
          index: index++,
          child: CardBox(
            radius: Radii.lg,
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : Space.md),
                    child: StepLine(number: i + 1, text: l.t(steps[i])),
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.emphasized,
          child: _tried && !_satisfied
              ? Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: status.restricted && !status.accessibility
                      ? NoticeCard(
                          icon: Icons.gpp_maybe_outlined,
                          title: l.t('restrictedTitle'),
                          body: l.t('restrictedBody'),
                          action: l.t('openAppInfo'),
                          onAction: Blocker.openAppDetails,
                        )
                      : NoticeCard(
                          icon: Icons.help_outline,
                          title: l.t(restart ? 'guardHelpTitle' : 'blockingHelpTitle'),
                          body: l.t(restart ? 'guardHelpBody' : 'blockingHelpBody'),
                        ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (restart && !status.battery) ...[
          const SizedBox(height: Space.md),
          Reveal(
            index: index++,
            child: NoticeCard(
              icon: Icons.battery_charging_full,
              color: Palette.primary,
              title: l.t('batteryTitle'),
              body: l.t('batteryDesc'),
              action: l.t('allow'),
              onAction: () {
                _guard.watch();
                Blocker.requestBatteryExemption();
              },
            ),
          ),
        ],
        if (!restart) ...[
          const SizedBox(height: Space.xl),
          for (final (icon, title, body) in const [
            (Icons.visibility_outlined, 'disclosureUseTitle', 'disclosureUseBody'),
            (Icons.lock_outline, 'disclosurePrivacyTitle', 'disclosurePrivacyBody'),
            (Icons.schedule, 'disclosureWhenTitle', 'disclosureWhenBody'),
          ])
            Reveal(index: index++, child: InfoPoint(icon: icon, title: l.t(title), body: l.t(body))),
        ],
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: BlockButton(
            label: l.t('notNow'),
            tone: BlockTone.secondary,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          flex: 2,
          child: BlockButton(
            label: l.t(_tried ? 'tryAgain' : (widget.restart ? 'openSettings' : 'turnOn')),
            icon: Icons.arrow_forward,
            onTap: _open,
          ),
        ),
      ],
    );
  }
}

class _Success extends StatelessWidget {
  const _Success();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.long,
      builder: (context, value, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Starburst(progress: value, color: Palette.success, size: 120),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Palette.success.withOpacity(0.12 * Curves.easeOut.transform(value)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: DrawnCheck(progress: Curves.easeOutCubic.transform(value), size: 44)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Opacity(
            opacity: value,
            child: Caps(
              l.t('blockingOn'),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2, color: Palette.success),
            ),
          ),
        ],
      ),
    );
  }
}
