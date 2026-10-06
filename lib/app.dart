import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'state/app_state.dart';
import 'state/guard_controller.dart';
import 'state/scope.dart';
import 'state/session_controller.dart';
import 'ui/shell.dart';

class HazmApp extends StatelessWidget {
  const HazmApp({super.key, required this.app, required this.session, required this.guard});

  final AppState app;
  final SessionController session;
  final GuardController guard;

  static final Map<String, ThemeData> _themes = {
    for (final code in const ['en', 'ar']) code: buildTheme(code)
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: app.language,
      builder: (context, language, _) => MaterialApp(
        title: 'HAZM',
        debugShowCheckedModeBanner: false,
        theme: _themes[language] ?? _themes['en'],
        themeAnimationDuration: Duration.zero,
        locale: Locale(language),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return AppScope(
            app: app,
            session: session,
            guard: guard,
            child: L10nScope(
              l10n: L10n(language),
              child: MediaQuery(
                data: media.copyWith(textScaler: media.textScaler.clamp(maxScaleFactor: 1.3)),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
        home: const HazmRoot(),
      ),
    );
  }
}
