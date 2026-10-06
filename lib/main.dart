import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'state/app_state.dart';
import 'state/guard_controller.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  final app = await AppState.load();
  runApp(HazmApp(app: app, session: SessionController(app), guard: GuardController()..attach()));
}
