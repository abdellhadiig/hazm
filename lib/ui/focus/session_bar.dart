import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../state/scope.dart';
import '../motion/effects.dart';
import '../motion/rolling.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';
import '../widgets/ticker.dart';

class SessionBar extends StatelessWidget {
  const SessionBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = context.session;
    final guard = context.guard;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([session, guard]),
      builder: (context, _) => SecondTicker(
        read: () => Fmt.ceilSeconds(session.paused ? session.pauseRemaining : session.remaining),
        builder: (context, seconds) {
          final paused = session.paused;
          final exposed = !paused && guard.exposed;
          final color = exposed
              ? Palette.warning
              : paused
                  ? Palette.warning
                  : Palette.primary;
          final label = exposed ? 'guardOff' : (paused ? 'barBreak' : 'barActive');
          return Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
            child: Pressable(
              onTap: onTap,
              scale: 0.98,
              child: AnimatedContainer(
                duration: Motion.medium,
                height: 48,
                padding: const EdgeInsetsDirectional.fromSTEB(Space.md, 0, Space.sm, 0),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Breathing(
                      enabled: !paused,
                      builder: (context, value) => Icon(
                        paused ? Icons.coffee : (exposed ? Icons.lock_open : Icons.lock),
                        color: color.withOpacity(0.7 + value * 0.3),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    RollingText(
                      Fmt.clock(Duration(seconds: seconds)),
                      duration: Motion.fast,
                      style: Typo.numeral.copyWith(fontSize: 15, color: Colors.white),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Caps(
                        l.t(label),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: exposed ? Palette.warning : Palette.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: Palette.textMuted),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
