import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../motion/reveal.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';
import '../widgets/sheet.dart';

const minSessionMinutes = 5;
const maxSessionMinutes = 240;

Future<int?> showDurationPicker(BuildContext context, int minutes) {
  return showHazmSheet<int>(
    context,
    title: (l) => l.t('setDuration'),
    builder: (_) => _DurationPicker(initial: minutes),
  );
}

class _DurationPicker extends StatefulWidget {
  const _DurationPicker({required this.initial});

  final int initial;

  @override
  State<_DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPicker> {
  static const _presets = [5, 15, 25, 30, 45, 60, 90, 120, 180, 240];
  late int _hours = widget.initial ~/ 60;
  late int _minutes = widget.initial % 60;
  late final _hoursController = FixedExtentScrollController(initialItem: _hours);
  late final _minutesController = FixedExtentScrollController(initialItem: _minutes);

  int get _total => (_hours * 60 + _minutes).clamp(minSessionMinutes, maxSessionMinutes);

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _preset(int total) {
    setState(() {
      _hours = total ~/ 60;
      _minutes = total % 60;
    });
    _hoursController.animateToItem(_hours, duration: Motion.medium, curve: Motion.ease);
    _minutesController.animateToItem(_minutes, duration: Motion.medium, curve: Motion.ease);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Reveal(
          child: SizedBox(
            height: 160,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  const Spacer(),
                  _Wheel(
                    label: l.t('hours'),
                    controller: _hoursController,
                    count: maxSessionMinutes ~/ 60 + 1,
                    onChanged: (value) => setState(() => _hours = value),
                  ),
                  const _Separator(),
                  _Wheel(
                    label: l.t('min'),
                    controller: _minutesController,
                    count: 60,
                    onChanged: (value) => setState(() => _minutes = value),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.xl),
        Reveal(
          index: 1,
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            alignment: WrapAlignment.center,
            children: [
              for (final preset in _presets)
                _PresetChip(
                  label: Fmt.preset(l, preset),
                  selected: preset == _total,
                  onTap: () => _preset(preset),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        Reveal(
          index: 2,
          child: BlockButton(
            label: l.t('confirm'),
            icon: Icons.check,
            onTap: () => Navigator.of(context).pop(_total),
          ),
        ),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({required this.label, required this.controller, required this.count, required this.onChanged});

  final String label;
  final FixedExtentScrollController controller;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        children: [
          Caps(label,
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Palette.textMuted)),
          const SizedBox(height: Space.xs),
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Palette.surfaceLight,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(color: Palette.primary.withOpacity(0.3)),
                    ),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: controller,
                  itemExtent: 44,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1.5,
                  perspective: 0.003,
                  overAndUnderCenterOpacity: 0.55,
                  onSelectedItemChanged: (value) {
                    Haptics.selection();
                    onChanged(value);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: count,
                    builder: (context, index) => Center(
                      child: Text(
                        index.toString().padLeft(2, '0'),
                        style: Typo.numeral.copyWith(fontSize: 32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg, left: Space.sm, right: Space.sm),
      child: Text(':', style: Typo.numeral.copyWith(fontSize: 36, color: Palette.textMuted)),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm + 2),
        decoration: BoxDecoration(
          color: selected ? Palette.primary.withOpacity(0.12) : Palette.surfaceLight,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? Palette.primary : Palette.divider, width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: Typo.chip.copyWith(color: selected ? Palette.primary : Palette.textSecondary),
        ),
      ),
    );
  }
}
