import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/scope.dart';
import '../motion/reveal.dart';
import '../widgets/dialogs.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';
import '../widgets/sheet.dart';

typedef _Edit = ({bool delete, String text});

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.onFocusTask});

  final ValueChanged<TaskItem> onFocusTask;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  bool _showDone = true;

  Future<void> _compose({TaskItem? task}) async {
    final result = await showHazmSheet<_Edit>(
      context,
      title: (l) => l.t(task == null ? 'newTask' : 'editTask'),
      builder: (_) => _TaskEditor(initial: task?.title ?? '', editing: task != null),
    );
    if (!mounted || result == null) return;
    final app = context.app;
    if (result.delete && task != null) {
      _delete(task);
      return;
    }
    final text = result.text.trim();
    if (text.isEmpty) return;
    if (task == null) {
      app.addTask(text);
      Haptics.light();
    } else {
      app.renameTask(task.id, text);
    }
  }

  void _delete(TaskItem task) {
    final app = context.app;
    final removed = app.removeTask(task.id);
    if (removed == null) return;
    final l = context.l10n;
    showToast(
      context,
      l.t('taskDeleted'),
      icon: Icons.delete_outline,
      color: Palette.danger,
      action: SnackBarAction(label: l.t('undo'), onPressed: () => app.restoreTask(removed.$1, removed.$2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final open = app.openTasks;
        final done = app.doneTasks;
        final total = open.length + done.length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Reveal(
                child: PageHeader(
                  eyebrow: l.t('objectives'),
                  title: l.t('tasksTitle'),
                  trailing: IconSquare(
                    icon: Icons.add,
                    tooltip: l.t('addTask'),
                    color: Palette.primary,
                    iconColor: Colors.black,
                    iconSize: 22,
                    glow: true,
                    onTap: _compose,
                  ),
                ),
              ),
              if (total > 0) ...[
                const SizedBox(height: Space.lg),
                Reveal(index: 1, child: _Progress(done: done.length, total: total)),
              ],
              const SizedBox(height: Space.xl),
              Expanded(
                child: total == 0
                    ? Center(
                        child: Reveal(
                          index: 1,
                          offset: const Offset(0, 24),
                          child: EmptyNote(l.t('noTasks'), icon: Icons.checklist),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: Space.xxl),
                        children: [
                          for (var i = 0; i < open.length; i++)
                            Reveal(
                              key: ValueKey('open-${open[i].id}'),
                              index: 2 + i.clamp(0, 8),
                              child: _TaskTile(
                                task: open[i],
                                onToggle: () => app.toggleTask(open[i].id),
                                onEdit: () => _compose(task: open[i]),
                                onDelete: () => _delete(open[i]),
                                onFocus: () => widget.onFocusTask(open[i]),
                              ),
                            ),
                          if (done.isNotEmpty) ...[
                            const SizedBox(height: Space.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: Pressable(
                                    onTap: () => setState(() => _showDone = !_showDone),
                                    haptic: false,
                                    scale: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: Space.sm),
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Caps(
                                              l.f('completedCount', {'count': '${done.length}'}),
                                              style: Typo.section,
                                            ),
                                          ),
                                          const SizedBox(width: Space.xs),
                                          AnimatedRotation(
                                            turns: _showDone ? 0 : -0.25,
                                            duration: Motion.medium,
                                            curve: Motion.emphasized,
                                            child: const Icon(Icons.expand_more, size: 18, color: Palette.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Pressable(
                                  onTap: app.clearDoneTasks,
                                  child: Padding(
                                    padding: const EdgeInsets.all(Space.sm),
                                    child: Caps(
                                      l.t('clear'),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2,
                                        color: Palette.danger,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.sm),
                            AnimatedSize(
                              duration: Motion.medium,
                              curve: Motion.emphasized,
                              alignment: AlignmentDirectional.topCenter,
                              child: _showDone
                                  ? Column(
                                      children: [
                                        for (final task in done)
                                          Reveal(
                                            key: ValueKey('done-${task.id}'),
                                            offset: const Offset(0, 10),
                                            child: _TaskTile(
                                              task: task,
                                              onToggle: () => app.toggleTask(task.id),
                                              onEdit: () => _compose(task: task),
                                              onDelete: () => _delete(task),
                                            ),
                                          ),
                                      ],
                                    )
                                  : const SizedBox(width: double.infinity),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fraction = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Caps(
                l.f('tasksSummary', {'open': '${total - done}', 'done': '$done'}),
                style: Typo.eyebrow,
              ),
            ),
            Text(
              '${Fmt.percent(done, total)}%',
              textDirection: TextDirection.ltr,
              style: Typo.numeral.copyWith(fontSize: 12, color: done == total ? Palette.success : Palette.primary),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Container(
          height: 3,
          decoration: BoxDecoration(color: Palette.surfaceLight, borderRadius: BorderRadius.circular(2)),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedFractionallySizedBox(
              duration: Motion.slow,
              curve: Motion.emphasized,
              widthFactor: fraction,
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
      ],
    );
  }
}

class _TaskTile extends StatefulWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onFocus,
  });

  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onFocus;

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  late bool _checked = widget.task.done;
  bool _pending = false;

  @override
  void didUpdateWidget(_TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pending) _checked = widget.task.done;
  }

  Future<void> _toggle() async {
    if (_pending) return;
    Haptics.light();
    setState(() {
      _checked = !_checked;
      _pending = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 420));
    _pending = false;
    if (mounted) widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final task = widget.task;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Dismissible(
        key: ValueKey('dismiss-${task.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => widget.onDelete(),
        background: Container(
          alignment: rtl ? Alignment.centerLeft : Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(color: Palette.danger, borderRadius: BorderRadius.circular(Radii.md)),
          child: const Icon(Icons.delete, color: Colors.white, size: 20),
        ),
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.emphasized,
          padding: const EdgeInsetsDirectional.only(start: Space.xs, end: Space.xs),
          decoration: BoxDecoration(
            color: _checked ? Palette.surface.withOpacity(0.5) : Palette.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: _checked ? Colors.transparent : Palette.divider),
          ),
          child: Row(
            children: [
              Pressable(
                onTap: _toggle,
                haptic: false,
                scale: 0.85,
                semanticLabel: l.t(_checked ? 'markOpen' : 'markDone'),
                child: Padding(
                  padding: const EdgeInsets.all(Space.sm + 2),
                  child: CheckSquare(checked: _checked),
                ),
              ),
              Expanded(
                child: Pressable(
                  onTap: widget.onEdit,
                  scale: 0.99,
                  semanticLabel: l.t('editTask'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.md + 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: _checked ? 1 : 0),
                          duration: Motion.slow,
                          curve: Motion.emphasized,
                          builder: (context, value, _) => Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Typo.item.copyWith(
                              color: Color.lerp(Colors.white, Palette.textMuted, value),
                              decoration: value > 0 ? TextDecoration.lineThrough : TextDecoration.none,
                              decorationColor: Palette.textMuted.withOpacity(value),
                              decorationThickness: 1.6,
                            ),
                          ),
                        ),
                        if (task.focusSeconds > 0) ...[
                          const SizedBox(height: Space.xs),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 11, color: Palette.primary),
                              const SizedBox(width: Space.xs),
                              Flexible(
                                child: Caps(
                                  l.f('taskFocused', {'time': Fmt.duration(l, task.focusSeconds)}),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                    color: Palette.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: Motion.medium,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: widget.onFocus != null && !_checked
                    ? Tooltip(
                        key: const ValueKey('focus'),
                        message: l.t('focusOnTask'),
                        excludeFromSemantics: true,
                        child: Pressable(
                          onTap: widget.onFocus,
                          semanticLabel: l.t('focusOnTask'),
                          scale: 0.85,
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsetsDirectional.only(end: Space.xs),
                            decoration: BoxDecoration(
                              color: Palette.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(Radii.sm),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, size: 22, color: Palette.primary),
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('none'), width: Space.sm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.initial, required this.editing});

  final String initial;
  final bool editing;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop<_Edit>((delete: false, text: text));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final editing = widget.editing;

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
              autofocus: true,
              maxLength: 120,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              decoration: InputDecoration(
                hintText: l.t('enterTask'),
                hintStyle: const TextStyle(color: Palette.textFaint),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md + 2),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Reveal(index: 1, child: BlockButton(label: l.t(editing ? 'save' : 'add'), onTap: _submit)),
        if (editing) ...[
          const SizedBox(height: Space.sm),
          Reveal(
            index: 2,
            child: BlockButton(
              label: l.t('deleteTask'),
              icon: Icons.delete_outline,
              tone: BlockTone.danger,
              onTap: () => Navigator.of(context).pop<_Edit>((delete: true, text: '')),
            ),
          ),
        ],
      ],
    );
  }
}
