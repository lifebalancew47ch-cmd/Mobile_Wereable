import 'package:flutter/material.dart';

class AppTheme {
  // --- Colores "Green Harmony" (Tema Claro) ---
  static const Color primaryGreen = Color(0xFF3E6F58);
  static const Color lightMint = Color(0xFFE9F1EC);

  // --- Colores "Midnight Executive" (Tema Oscuro) ---
  static const Color midnightDeepNavy = Color(0xFF0B1220); // Fondo oscuro profundo
  static const Color midnightNavyCard = Color(0xFF161F30); // Fondo de tarjetas oscuro
  static const Color cyanAccent = Color(0xFF00C2FF); // Acento cian brillante
  static const Color blueAccent = Color(0xFF4A80FF); // Acento azul

  static const String fontFamily = 'Oswald';

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontWeight: FontWeight.w700),
    displaySmall: TextStyle(fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontWeight: FontWeight.w500),
    titleMedium: TextStyle(fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontWeight: FontWeight.w500),
  );

  /// Borde redondeado "orgánico" usado en tarjetas y contenedores principales
  /// para alejar la UI del look cuadradón.
  static const double radiusLarge = 28;
  static const double radiusMedium = 20;
  static const double radiusSmall = 14;

  static final RoundedRectangleBorder roundedCard = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radiusLarge),
  );

  // TEMA CLARO: Green Harmony
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        surface: lightMint,
        brightness: Brightness.light,
      ),
      textTheme: _textTheme.apply(fontFamily: fontFamily),
      scaffoldBackgroundColor: lightMint,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryGreen),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primaryGreen,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black12,
        shape: roundedCard,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: roundedCard,
        backgroundColor: Colors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 8,
      ),
    );
  }

  // TEMA OSCURO: Midnight Executive
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cyanAccent,
        primary: blueAccent,
        surface: midnightDeepNavy,
        onSurface: Colors.white,
        brightness: Brightness.dark,
      ),
      textTheme: _textTheme.apply(fontFamily: fontFamily, bodyColor: Colors.white, displayColor: Colors.white),
      scaffoldBackgroundColor: midnightDeepNavy,
      cardTheme: CardThemeData(
        color: midnightNavyCard,
        elevation: 0,
        shape: roundedCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B1220),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: roundedCard,
        backgroundColor: midnightNavyCard,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? cyanAccent : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? cyanAccent.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 8,
      ),
    );
  }
}
