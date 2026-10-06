import 'package:flutter/material.dart';

abstract final class Palette {
  static const primary = Color(0xFFF96B06);
  static const primaryDark = Color(0xFFD45A05);
  static const primaryGlow = Color(0xFFFFB27A);
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const surfaceLight = Color(0xFF2A2A2A);
  static const divider = Color(0xFF2D2D2D);
  static const text = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const textFaint = Color(0xFF475569);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFFBBF24);
}

abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class Radii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

abstract final class Motion {
  static const instant = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const long = Duration(milliseconds: 760);
  static const stagger = Duration(milliseconds: 45);
  static const ease = Curves.easeOutCubic;
  static const easeInOut = Curves.easeInOutCubic;
  static const enter = Cubic(0.05, 0.7, 0.1, 1);
  static const exit = Cubic(0.3, 0, 0.8, 0.15);
  static const emphasized = Cubic(0.2, 0, 0, 1);
  static const spring = Curves.easeOutBack;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

abstract final class Fonts {
  static const latin = 'SpaceGrotesk';
  static const arabic = 'NotoKufiArabic';
}

abstract final class Typo {
  static const tabular = [FontFeature.tabularFigures()];

  static const eyebrow = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: Palette.textMuted,
  );

  static const brand = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white);

  static const title = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white);

  static const sheetTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white);

  static const section = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: Palette.textMuted,
  );

  static const statLabel = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: Palette.textMuted,
  );

  static const statValue = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    fontFeatures: tabular,
  );

  static const body = TextStyle(fontSize: 13, color: Palette.textSecondary, height: 1.5);

  static const small = TextStyle(fontSize: 11, color: Palette.textMuted, height: 1.4);

  static const item = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white);

  static const strong = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white);

  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black);

  static const chip = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Palette.textSecondary);

  static const numeral = TextStyle(
    fontFamily: Fonts.latin,
    fontFamilyFallback: [Fonts.arabic],
    fontWeight: FontWeight.w700,
    color: Colors.white,
    fontFeatures: tabular,
  );
}

class HazmPageTransitions extends PageTransitionsBuilder {
  const HazmPageTransitions();

  static final _incomingFade = Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: const Interval(0.2, 1)));
  static final _incomingSlide = Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero);
  static final _incomingScale = Tween<double>(begin: 0.985, end: 1);
  static final _outgoingFade = Tween<double>(begin: 1, end: 0).chain(CurveTween(curve: const Interval(0, 0.6)));
  static final _outgoingScale = Tween<double>(begin: 1, end: 0.965);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Motion.exit);
    final under = CurvedAnimation(parent: secondaryAnimation, curve: Motion.emphasized, reverseCurve: Motion.exit);
    return FadeTransition(
      opacity: _outgoingFade.animate(under),
      child: ScaleTransition(
        scale: _outgoingScale.animate(under),
        child: FadeTransition(
          opacity: _incomingFade.animate(enter),
          child: SlideTransition(
            position: _incomingSlide.animate(enter),
            child: ScaleTransition(scale: _incomingScale.animate(enter), child: child),
          ),
        ),
      ),
    );
  }
}

ThemeData buildTheme(String language) {
  final arabic = language == 'ar';
  const scheme = ColorScheme.dark(
    primary: Palette.primary,
    onPrimary: Colors.black,
    secondary: Palette.primary,
    onSecondary: Colors.black,
    surface: Palette.surface,
    onSurface: Palette.text,
    error: Palette.danger,
    onError: Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: arabic ? Fonts.arabic : Fonts.latin,
    fontFamilyFallback: [arabic ? Fonts.latin : Fonts.arabic],
    scaffoldBackgroundColor: Palette.background,
    canvasColor: Palette.background,
    dividerColor: Palette.divider,
    splashFactory: InkRipple.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Palette.primary,
      selectionColor: Palette.primary.withOpacity(0.35),
      selectionHandleColor: Palette.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.surfaceLight,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      contentTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
      actionTextColor: Palette.primary,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: Palette.surfaceLight, borderRadius: BorderRadius.circular(Radii.sm)),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: Palette.primary,
      inactiveTrackColor: Palette.surfaceLight,
      thumbColor: Palette.primary,
      overlayColor: Palette.primary.withOpacity(0.2),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 0, pressedElevation: 0),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      trackShape: const RoundedRectSliderTrackShape(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.black : Palette.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Palette.primary : Palette.surfaceLight,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Palette.primary : Palette.divider,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.primary),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: HazmPageTransitions(),
        TargetPlatform.iOS: HazmPageTransitions(),
      },
    ),
  );
}
