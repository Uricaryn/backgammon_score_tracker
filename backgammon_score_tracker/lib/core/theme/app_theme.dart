import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF8B4513); // Saddle Brown
  static const secondaryColor = Color(0xFFDEB887); // Burlywood
  static const tertiaryColor = Color(0xFFD2691E); // Koyu Turuncu
  static const backgroundColor = Color(0xFFF5F5DC); // Beige
  static const surfaceColor = Colors.white;
  static const errorColor = Color(0xFFB00020);

  static InputDecorationTheme get _inputDecorationTheme => InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      );

  static FilledButtonThemeData get _filledButtonTheme => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  static ColorScheme _getColorScheme(Brightness brightness) =>
      ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        brightness: brightness,
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: _getColorScheme(Brightness.light),
        cardColor: surfaceColor,
        inputDecorationTheme: _inputDecorationTheme,
        filledButtonTheme: _filledButtonTheme,
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: _getColorScheme(Brightness.dark),
        cardColor: const Color(0xFF1E1E1E),
        inputDecorationTheme: _inputDecorationTheme,
        filledButtonTheme: _filledButtonTheme,
      );
}
