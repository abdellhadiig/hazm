import 'package:flutter/widgets.dart';

import 'app_state.dart';
import 'guard_controller.dart';
import 'session_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.app, required this.session, required this.guard, required super.child});

  final AppState app;
  final SessionController session;
  final GuardController guard;

  static AppScope of(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      app != oldWidget.app || session != oldWidget.session || guard != oldWidget.guard;
}

extension AppScopeContext on BuildContext {
  AppState get app => AppScope.of(this).app;

  SessionController get session => AppScope.of(this).session;

  GuardController get guard => AppScope.of(this).guard;
}
