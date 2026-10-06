import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../motion/reveal.dart';
import 'kit.dart';
import 'pressable.dart';

Future<T?> showHazmDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black87,
    transitionDuration: Motion.slow,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Motion.exit);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6), reverseCurve: Curves.easeIn),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curve),
          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curve), child: child),
        ),
      );
    },
  );
}

class DialogCard extends StatelessWidget {
  const DialogCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.xl)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              width: double.infinity,
              padding: padding,
              decoration: BoxDecoration(
                color: Palette.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: Palette.divider),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String? detail,
  IconData? icon,
  bool danger = false,
}) async {
  final accent = danger ? Palette.danger : Palette.primary;
  final result = await showHazmDialog<bool>(
    context,
    builder: (context) => DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Reveal(
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: Space.md),
                ],
                Expanded(
                  child: Caps(
                    title,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: danger ? accent : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          Reveal(index: 1, child: Text(message, style: Typo.body.copyWith(color: Colors.white))),
          if (detail != null) ...[
            const SizedBox(height: Space.xs),
            Reveal(index: 2, child: Text(detail, style: Typo.small)),
          ],
          const SizedBox(height: Space.xl),
          Reveal(
            index: 3,
            child: Row(
              children: [
                Expanded(
                  child: BlockButton(
                    label: context.t('cancel'),
                    tone: BlockTone.secondary,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(Radii.md)),
                      child: Text(
                        action,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: danger ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

void showToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.info_outline,
  Color color = Palette.primary,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        action: action,
        content: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: Space.md - 2),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
