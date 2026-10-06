import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../platform/blocker.dart';
import '../state/scope.dart';
import '../state/session_controller.dart';
import 'focus/focus_page.dart';
import 'focus/result_dialog.dart';
import 'focus/session_actions.dart';
import 'focus/session_bar.dart';
import 'motion/reveal.dart';
import 'settings/settings_sheet.dart';
import 'setup/permissions_screen.dart';
import 'stats/stats_page.dart';
import 'tasks/tasks_page.dart';
import 'widgets/pressable.dart';

class HazmRoot extends StatelessWidget {
  const HazmRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => AnimatedSwitcher(
        duration: Motion.slow,
        switchInCurve: Motion.emphasized,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(animation), child: child),
        ),
        child: app.preferences.onboarded
            ? const HazmShell(key: ValueKey('shell'))
            : PermissionsScreen(
                key: const ValueKey('setup'),
                firstRun: true,
                onDone: () => app.updatePreferences(app.preferences.copyWith(onboarded: true)),
              ),
      ),
    );
  }
}

class HazmShell extends StatefulWidget {
  const HazmShell({super.key});

  @override
  State<HazmShell> createState() => _HazmShellState();
}

class _HazmShellState extends State<HazmShell> with WidgetsBindingObserver {
  final _focusRequest = ValueNotifier<TaskItem?>(null);
  late final SessionController _session;
  int _tab = 0;
  bool _presenting = false;
  bool _optionsOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Blocker.onBlocked(_checkBlocked);
    _session = context.session..addListener(_onSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _session.refresh();
      _checkBlocked();
      context.app.checkForUpdates();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Blocker.onBlocked(null);
    _session.removeListener(_onSession);
    _focusRequest.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _session.setForeground(true);
      _checkBlocked();
      context.app.checkForUpdates();
    } else if (state == AppLifecycleState.paused) {
      _session.setForeground(false);
    }
  }

  void _onSession() {
    if (_session.hasFinished) _presentResults();
  }

  Future<void> _presentResults() async {
    if (_presenting) return;
    _presenting = true;
    try {
      for (var record = _session.takeFinished(); record != null; record = _session.takeFinished()) {
        if (!mounted) return;
        if (_tab != 0) setState(() => _tab = 0);
        await presentResult(context, record);
      }
    } finally {
      _presenting = false;
    }
  }

  Future<void> _checkBlocked() async {
    final blocked = await Blocker.takeBlocked();
    if (blocked == null || !mounted) return;
    await _session.refresh();
    if (!mounted || !_session.active || _session.paused || _optionsOpen) return;
    _optionsOpen = true;
    _select(0);
    try {
      await showUnlockOptions(context, blocked: blocked);
    } finally {
      _optionsOpen = false;
    }
  }

  void _select(int index) {
    if (index != _tab) setState(() => _tab = index);
  }

  void _focusOn(TaskItem task) {
    if (_session.active) return;
    _focusRequest.value = task;
    _select(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ListenableBuilder(
              listenable: _session,
              builder: (context, _) => AnimatedSize(
                duration: Motion.medium,
                curve: Motion.emphasized,
                alignment: Alignment.topCenter,
                child: _session.active && _tab != 0
                    ? Reveal(offset: const Offset(0, -12), child: SessionBar(onTap: () => _select(0)))
                    : const SizedBox(width: double.infinity),
              ),
            ),
            Expanded(
              child: _TabStage(
                index: _tab,
                children: [
                  FocusPage(focusRequest: _focusRequest, onOpenSettings: () => showSettingsSheet(context)),
                  const StatsPage(),
                  TasksPage(onFocusTask: _focusOn),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _NavBar(index: _tab, onSelect: _select),
    );
  }
}

class _TabStage extends StatefulWidget {
  const _TabStage({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_TabStage> createState() => _TabStageState();
}

class _TabStageState extends State<_TabStage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.slow, value: 1);
  late final List<int> _generations = List.filled(widget.children.length, 0);
  late int _current = widget.index;
  int? _previous;

  @override
  void didUpdateWidget(_TabStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == _current) return;
    _previous = _current;
    _current = widget.index;
    _generations[_current]++;
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
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
    final previous = _previous;
    final direction = (previous == null || _current > previous ? 1.0 : -1.0) * (rtl ? -1 : 1);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final moving = _controller.isAnimating;
        final t = Motion.emphasized.transform(_controller.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _layer(
                i,
                visible: i == _current || (moving && i == previous),
                opacity: i == _current ? t : (1 - t * 1.6).clamp(0.0, 1.0),
                shift: i == _current ? direction * 28 * (1 - t) : -direction * 14 * t,
              ),
          ],
        );
      },
    );
  }

  Widget _layer(int index, {required bool visible, required double opacity, required double shift}) {
    return Offstage(
      offstage: !visible,
      child: IgnorePointer(
        ignoring: index != _current,
        child: Opacity(
          opacity: visible ? opacity : 0,
          child: Transform.translate(
            offset: Offset(visible ? shift : 0, 0),
            child: TickerMode(
              enabled: index == _current,
              child: RevealScope(generation: _generations[index], child: widget.children[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (Icons.timer_outlined, Icons.timer, l.t('tabFocus')),
      (Icons.bar_chart_outlined, Icons.bar_chart, l.t('tabStats')),
      (Icons.list_outlined, Icons.list, l.t('tabTasks')),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        border: Border(top: BorderSide(color: Palette.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositionedDirectional(
                    duration: Motion.slow,
                    curve: Motion.emphasized,
                    start: width * index,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.xs),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Palette.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Pressable(
                            onTap: () => onSelect(i),
                            scale: 0.92,
                            semanticLabel: items[i].$3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: Space.sm + Space.xs),
                              child: _NavItem(
                                icon: items[i].$1,
                                activeIcon: items[i].$2,
                                label: items[i].$3,
                                active: i == index,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.active});

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Palette.primary : Palette.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: Motion.medium,
          switchInCurve: Motion.spring,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.0).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(active ? activeIcon : icon, key: ValueKey(active), size: 22, color: color),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: Motion.medium,
          style: DefaultTextStyle.of(context).style.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: color,
              ),
          child: Text(label, maxLines: 1),
        ),
      ],
    );
  }
}
