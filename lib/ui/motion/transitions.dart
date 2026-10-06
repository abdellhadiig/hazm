import 'package:flutter/widgets.dart';

import '../../core/theme.dart';

AnimatedSwitcherTransitionBuilder fadeThrough(Key current, {Offset offset = const Offset(0, 0.25)}) {
  return (child, animation) {
    final incoming = child.key == current;
    final opacity = CurvedAnimation(
      parent: animation,
      curve: incoming ? const Interval(0.4, 1, curve: Curves.easeOut) : const Interval(0.6, 1, curve: Curves.easeIn),
    );
    final position = Tween<Offset>(begin: incoming ? offset : -offset, end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: Motion.emphasized));
    return FadeTransition(opacity: opacity, child: SlideTransition(position: position, child: child));
  };
}

Widget stackLayout(Widget? current, List<Widget> previous, {AlignmentGeometry alignment = Alignment.center}) {
  return Stack(alignment: alignment, children: [...previous, if (current != null) current]);
}
