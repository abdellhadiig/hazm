import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../motion/effects.dart';
import 'pressable.dart';

class Caps extends StatelessWidget {
  const Caps(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: context.l10n.isArabic ? style.copyWith(letterSpacing: 0) : style,
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.eyebrow, required this.title, this.trailing});

  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Caps(eyebrow, style: Typo.eyebrow),
              const SizedBox(height: 2),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.title),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Space.md), trailing!],
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.only(bottom: Space.sm),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.divider))),
            child: Caps(text, style: Typo.section),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: Space.md),
          Flexible(child: Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: trailing)),
        ],
      ],
    );
  }
}

class CardBox extends StatelessWidget {
  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.md + 2),
    this.color = Palette.surface,
    this.border = Palette.divider,
    this.radius = Radii.md,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color border;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, scale: 0.985, child: box);
  }
}

enum BlockTone { primary, secondary, danger }

class BlockButton extends StatelessWidget {
  const BlockButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tone = BlockTone.primary,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final BlockTone tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border, size) = switch (tone) {
      BlockTone.primary => (Palette.primary, Colors.black, Palette.primary, 16.0),
      BlockTone.secondary => (Palette.surfaceLight, Palette.textSecondary, Palette.surfaceLight, 14.0),
      BlockTone.danger => (Palette.danger.withOpacity(0.08), Palette.danger, Palette.danger.withOpacity(0.4), 12.0),
    };
    return Pressable(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: foreground))
            else if (icon != null)
              Icon(icon, size: 20, color: foreground),
            if (busy || icon != null) const SizedBox(width: Space.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TintPill extends StatelessWidget {
  const TintPill({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
    this.icon,
    this.compact = false,
  });

  static const textStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2);
  static const horizontalPadding = Space.md;

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconOnly = compact && icon != null;
    final pill = Pressable(
      onTap: onTap,
      scale: 0.94,
      semanticLabel: iconOnly ? label : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          child: Container(
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? Space.sm + 2 : horizontalPadding),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: iconOnly
                ? Icon(icon, size: 18, color: color)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: Space.xs)],
                      Text(label, maxLines: 1, style: textStyle.copyWith(color: color)),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (!iconOnly) return pill;
    return Tooltip(message: label, excludeFromSemantics: true, child: pill);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.filled = false});

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2, vertical: Space.xs),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : Palette.surfaceLight,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Caps(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: color),
      ),
    );
  }
}

class IconSquare extends StatelessWidget {
  const IconSquare({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color = Palette.surfaceLight,
    this.iconColor = Palette.textMuted,
    this.size = 48,
    this.iconSize = 20,
    this.glow = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color color;
  final Color iconColor;
  final double size;
  final double iconSize;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onTap,
      semanticLabel: tooltip,
      scale: 0.92,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow:
              glow ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, excludeFromSemantics: true, child: button);
  }
}

class CloseCircle extends StatelessWidget {
  const CloseCircle({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.t('close');
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        scale: 0.9,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(Space.xs + 2),
              decoration: const BoxDecoration(color: Palette.surfaceLight, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Palette.textMuted, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

class CheckSquare extends StatelessWidget {
  const CheckSquare({super.key, required this.checked, this.size = 22});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.emphasized,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: checked ? Palette.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.xs),
        border: Border.all(color: checked ? Palette.primary : Palette.divider, width: 2),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: checked ? 1 : 0),
        duration: checked ? Motion.slow : Motion.fast,
        curve: Motion.emphasized,
        builder: (context, value, _) =>
            Center(child: DrawnCheck(progress: value, color: Colors.black, size: size * 0.82, stroke: 2.6)),
      ),
    );
  }
}

class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final value in values)
              Pressable(
                onTap: () {
                  if (enabled && value != selected) onChanged!(value);
                },
                scale: 0.94,
                child: AnimatedContainer(
                  duration: Motion.fast,
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm + 2),
                  decoration: BoxDecoration(
                    color: value == selected ? Palette.primary.withOpacity(0.12) : Palette.surfaceLight,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(
                      color: value == selected ? Palette.primary : Palette.divider,
                      width: value == selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    labelOf(value),
                    style: Typo.chip.copyWith(color: value == selected ? Palette.primary : Palette.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ValueBadge extends StatelessWidget {
  const ValueBadge(this.text, {super.key, this.width = 56});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
      decoration: BoxDecoration(
        color: Palette.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        text,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.primary),
      ),
    );
  }
}

class NumberStepper extends StatelessWidget {
  const NumberStepper({super.key, required this.value, required this.min, required this.max, required this.onChanged});

  final int value;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, int next) {
      final active = onChanged != null && next >= min && next <= max;
      return Pressable(
        onTap: active
            ? () {
                Haptics.selection();
                onChanged!(next);
              }
            : null,
        haptic: false,
        scale: 0.9,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: Palette.surfaceLight, borderRadius: BorderRadius.circular(Radii.sm)),
          child: Icon(icon, size: 18, color: active ? Colors.white : Palette.textMuted),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        step(Icons.remove, value - 1),
        const SizedBox(width: Space.sm),
        ValueBadge('$value', width: 44),
        const SizedBox(width: Space.sm),
        step(Icons.add, value + 1),
      ],
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 56, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: Space.md),
          ],
          Caps(
            text,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, letterSpacing: 1, color: Palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class InfoPoint extends StatelessWidget {
  const InfoPoint({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Caps(
                  title,
                  style:
                      const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white),
                ),
                const SizedBox(height: Space.xs),
                Text(body, style: Typo.small.copyWith(color: Palette.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StepLine extends StatelessWidget {
  const StepLine({super.key, required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Palette.primary),
            borderRadius: BorderRadius.circular(Radii.xs),
          ),
          child: Text('$number', style: Typo.numeral.copyWith(fontSize: 12, color: Palette.primary)),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: Typo.small.copyWith(color: Colors.white, height: 1.45, fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.color = Palette.warning,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      color: color.withOpacity(0.06),
      border: color.withOpacity(0.3),
      radius: Radii.lg,
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Caps(
                  title,
                  maxLines: 2,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(body, style: Typo.small.copyWith(color: Palette.textSecondary, height: 1.6)),
          if (action != null && onAction != null) ...[
            const SizedBox(height: Space.md),
            BlockButton(label: action!, tone: BlockTone.secondary, onTap: onAction),
          ],
        ],
      ),
    );
  }
}
