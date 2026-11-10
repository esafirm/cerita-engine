import 'package:flutter/material.dart';

/// Night-sky palette of the anime VN skin.
abstract final class CeritaColors {
  static const night = Color(0xFF0E0F1F);
  static const surface = Color(0xFF181A30);
  static const surfaceHigh = Color(0xFF23264A);
  static const blossom = Color(0xFFFF7EB6);
  static const lavender = Color(0xFFA99BFF);
  static const moon = Color(0xFFF5F3FF);

  static const accent = LinearGradient(colors: [blossom, lavender]);
}

abstract final class CeritaTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: CeritaColors.blossom, brightness: Brightness.dark).copyWith(
      primary: CeritaColors.blossom,
      onPrimary: CeritaColors.night,
      secondary: CeritaColors.lavender,
      surface: CeritaColors.surface,
      surfaceContainerHighest: CeritaColors.surfaceHigh,
      onSurface: CeritaColors.moon,
    );
    const rounded = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18)));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: CeritaColors.night,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: CeritaColors.moon,
        ),
      ),
      cardTheme: CardThemeData(color: CeritaColors.surfaceHigh.withAlpha(220), shape: rounded),
      dialogTheme: const DialogThemeData(backgroundColor: CeritaColors.surface, shape: rounded),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: CeritaColors.surface),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CeritaColors.surfaceHigh,
        contentTextStyle: const TextStyle(color: CeritaColors.moon),
        shape: rounded,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: const StadiumBorder(), textStyle: const TextStyle(letterSpacing: 1.2)),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {for (final platform in TargetPlatform.values) platform: const CeritaPageTransitionsBuilder()},
      ),
    );
  }
}

/// Menu-to-menu transition: the new page fades in while settling from a slight zoom,
/// the page underneath recedes and dims.
class CeritaPageTransitionsBuilder extends PageTransitionsBuilder {
  const CeritaPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 450);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.4).animate(exit),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.94).animate(exit),
        child: FadeTransition(
          opacity: enter,
          child: ScaleTransition(scale: Tween(begin: 1.06, end: 1.0).animate(enter), child: child),
        ),
      ),
    );
  }
}
