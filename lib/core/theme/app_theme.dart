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

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontWeight: FontWeight.bold),
    displayMedium: TextStyle(fontWeight: FontWeight.bold),
    displaySmall: TextStyle(fontWeight: FontWeight.bold),
    headlineLarge: TextStyle(fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontWeight: FontWeight.w600),
  );

  // TEMA CLARO: Green Harmony
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        surface: lightMint,
        brightness: Brightness.light,
      ),
      textTheme: _textTheme,
      scaffoldBackgroundColor: lightMint,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryGreen),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // TEMA OSCURO: Midnight Executive
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cyanAccent,
        primary: blueAccent,
        surface: midnightDeepNavy,
        onSurface: Colors.white,
        brightness: Brightness.dark,
      ),
      textTheme: _textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      scaffoldBackgroundColor: midnightDeepNavy,
      cardTheme: CardThemeData(
        color: midnightNavyCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B1220),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? cyanAccent : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? cyanAccent.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
      ),
    );
  }
}
