import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../motion/reveal.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';
import '../widgets/sheet.dart';

typedef Objective = ({String? text, String? taskId});

const Objective noObjective = (text: null, taskId: null);

Future<Objective?> showObjectiveSheet(
  BuildContext context, {
  required List<TaskItem> tasks,
  required Objective current,
}) {
  return showHazmSheet<Objective>(
    context,
    title: (l) => l.t('objective'),
    builder: (_) => _ObjectiveSheet(tasks: tasks, current: current),
  );
}

class _ObjectiveSheet extends StatefulWidget {
  const _ObjectiveSheet({required this.tasks, required this.current});

  final List<TaskItem> tasks;
  final Objective current;

  @override
  State<_ObjectiveSheet> createState() => _ObjectiveSheetState();
}

class _ObjectiveSheetState extends State<_ObjectiveSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current.taskId == null ? widget.current.text ?? '' : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && widget.current.taskId != null) {
      Navigator.of(context).pop(widget.current);
      return;
    }
    Navigator.of(context).pop<Objective>((text: text.isEmpty ? null : text, taskId: null));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tasks = widget.tasks.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reveal(
          child: Container(
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: Palette.divider),
            ),
            child: TextField(
              controller: _controller,
              maxLength: 80,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              decoration: InputDecoration(
                hintText: l.t('objectiveHint'),
                hintStyle: const TextStyle(color: Palette.textFaint),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md + 2),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          Caps(l.t('fromTasks'), style: Typo.eyebrow),
          const SizedBox(height: Space.sm),
          for (var i = 0; i < tasks.length; i++)
            Reveal(
              index: i + 1,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: _TaskOption(
                  task: tasks[i],
                  selected: tasks[i].id == widget.current.taskId,
                  onTap: () => Navigator.of(context).pop<Objective>((text: tasks[i].title, taskId: tasks[i].id)),
                ),
              ),
            ),
        ],
        const SizedBox(height: Space.lg),
        BlockButton(label: l.t('confirm'), icon: Icons.check, onTap: _submit),
        if (widget.current.text != null) ...[
          const SizedBox(height: Space.sm),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop<Objective>(noObjective),
              child: Text(
                l.t('clearObjective'),
                style: const TextStyle(color: Palette.textMuted, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TaskOption extends StatelessWidget {
  const _TaskOption({required this.task, required this.selected, required this.onTap});

  final TaskItem task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md + 2),
        decoration: BoxDecoration(
          color: selected ? Palette.primary.withOpacity(0.08) : Palette.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: selected ? Palette.primary.withOpacity(0.6) : Palette.divider),
        ),
        child: Row(
          children: [
            CheckSquare(checked: selected),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.item),
            ),
          ],
        ),
      ),
    );
  }
}
