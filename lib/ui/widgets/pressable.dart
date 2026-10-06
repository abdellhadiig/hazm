import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) Haptics.selection();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1,
          duration: _pressed ? const Duration(milliseconds: 90) : Motion.medium,
          curve: _pressed ? Curves.easeOut : Motion.spring,
          child: AnimatedOpacity(
            opacity: _enabled ? 1 : 0.42,
            duration: Motion.fast,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
