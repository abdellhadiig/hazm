import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import 'kit.dart';

typedef SheetTitle = String Function(L10n l);

Future<T?> showHazmSheet<T>(
  BuildContext context, {
  required SheetTitle title,
  required WidgetBuilder builder,
  EdgeInsetsGeometry padding = const EdgeInsets.all(Space.xl),
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    sheetAnimationStyle: AnimationStyle(
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
    ),
    builder: (context) => HazmSheet(
      title: title,
      padding: scrollable ? padding : EdgeInsets.zero,
      scrollable: scrollable,
      child: builder(context),
    ),
  );
}

class HazmSheet extends StatelessWidget {
  const HazmSheet({
    super.key,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(Space.xl),
    this.scrollable = true,
  });

  final SheetTitle title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(Space.md),
          constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(color: Palette.divider),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.lg + 4, Space.sm, Space.sm, Space.sm),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.divider))),
                  child: Row(
                    children: [
                      Expanded(child: Caps(title(context.l10n), style: Typo.sheetTitle)),
                      CloseCircle(onTap: () => Navigator.of(context).maybePop()),
                    ],
                  ),
                ),
                Flexible(
                  child: scrollable
                      ? SingleChildScrollView(padding: padding, child: child)
                      : Padding(padding: padding, child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SheetLayout extends StatelessWidget {
  const SheetLayout({super.key, required this.body, required this.footer});

  final Widget body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.md),
            child: body,
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.xl),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.divider))),
          child: footer,
        ),
      ],
    );
  }
}
