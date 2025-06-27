import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Colors
  static const primaryColor = Color(0xFF8B4513); // Saddle Brown
  static const secondaryColor = Color(0xFFDEB887); // Burlywood
  static const tertiaryColor = Color(0xFFD2691E); // Koyu Turuncu
  static const backgroundColor = Color(0xFFF5F5DC); // Beige
  static const surfaceColor = Colors.white;
  static const errorColor = Color(0xFFB00020);

  // Dark Theme Colors - Daha soft ve göz dostu
  static const darkPrimaryColor = Color(0xFFD4AF37); // Altın sarısı
  static const darkSecondaryColor = Color(0xFF8B7355); // Kahverengi
  static const darkTertiaryColor = Color(0xFFB8860B); // Koyu altın
  static const darkBackgroundColor =
      Color(0xFF2A2A2A); // Daha açık gri (önceden 1A1A1A)
  static const darkSurfaceColor =
      Color(0xFF3A3A3A); // Daha açık gri (önceden 2D2D2D)
  static const darkErrorColor = Color(0xFFCF6679); // Koyu kırmızı

  // Dark Mode için ek renkler
  static const darkSurfaceVariantColor =
      Color(0xFF4A4A4A); // Daha açık surface variant
  static const darkOutlineColor = Color(0xFF6A6A6A); // Daha açık outline
  static const darkOnSurfaceColor =
      Color(0xFFE0E0E0); // Daha yumuşak metin rengi
  static const darkOnSurfaceVariantColor =
      Color(0xFFB0B0B0); // Daha yumuşak variant metin

  // Backgammon Board Colors
  static const boardLightColor = Color(0xFFF5E6D3); // Açık bej
  static const boardDarkColor = Color(0xFF8B4513); // Kahverengi
  static const boardBorderColor = Color(0xFF654321); // Koyu kahverengi

  // Dark Mode Backgammon Board Colors - Daha soft
  static const darkBoardLightColor =
      Color(0xFF4A4A4A); // Daha açık gri (önceden 3A3A3A)
  static const darkBoardDarkColor =
      Color(0xFF6D5D4E); // Daha açık kahverengi (önceden 5D4037)
  static const darkBoardBorderColor =
      Color(0xFF9D8E83); // Daha açık kahverengi (önceden 8D6E63)

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

  static CardThemeData get _cardTheme => CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      );

  static ColorScheme _getLightColorScheme() => ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        background: backgroundColor,
        surface: surfaceColor,
        error: errorColor,
        brightness: Brightness.light,
      );

  static ColorScheme _getDarkColorScheme() => ColorScheme(
        brightness: Brightness.dark,
        primary: darkPrimaryColor,
        onPrimary: Colors.black,
        primaryContainer: darkPrimaryColor.withOpacity(0.2),
        onPrimaryContainer: darkPrimaryColor,
        secondary: darkSecondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: darkSecondaryColor.withOpacity(0.2),
        onSecondaryContainer: darkSecondaryColor,
        tertiary: darkTertiaryColor,
        onTertiary: Colors.white,
        tertiaryContainer: darkTertiaryColor.withOpacity(0.2),
        onTertiaryContainer: darkTertiaryColor,
        error: darkErrorColor,
        onError: Colors.white,
        errorContainer: darkErrorColor.withOpacity(0.2),
        onErrorContainer: darkErrorColor,
        background: darkBackgroundColor,
        onBackground: darkOnSurfaceColor,
        surface: darkSurfaceColor,
        onSurface: darkOnSurfaceColor,
        surfaceVariant: darkSurfaceVariantColor,
        onSurfaceVariant: darkOnSurfaceVariantColor,
        outline: darkOutlineColor,
        outlineVariant: darkOutlineColor.withOpacity(0.5),
        shadow: Colors.black.withOpacity(0.3),
        scrim: Colors.black.withOpacity(0.5),
        inverseSurface: Colors.white,
        onInverseSurface: Colors.black,
        inversePrimary: darkPrimaryColor.withOpacity(0.8),
        surfaceTint: darkPrimaryColor.withOpacity(0.1),
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: _getLightColorScheme(),
        cardTheme: _cardTheme,
        inputDecorationTheme: _inputDecorationTheme,
        filledButtonTheme: _filledButtonTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: surfaceColor,
          foregroundColor: primaryColor,
          elevation: 0,
          centerTitle: true,
        ),
        scaffoldBackgroundColor: backgroundColor,
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: _getDarkColorScheme(),
        cardTheme: _cardTheme,
        inputDecorationTheme: _inputDecorationTheme,
        filledButtonTheme: _filledButtonTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: darkSurfaceColor.withOpacity(0.95),
          foregroundColor: darkPrimaryColor,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        scaffoldBackgroundColor: darkBackgroundColor,
        shadowColor: Colors.black.withOpacity(0.2),
        dividerColor: darkOutlineColor.withOpacity(0.3),
      );

  // Backgammon Board Colors based on theme
  static Color getBoardLightColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBoardLightColor : boardLightColor;
  }

  static Color getBoardDarkColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBoardDarkColor : boardDarkColor;
  }

  static Color getBoardBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBoardBorderColor : boardBorderColor;
  }

  // Gradient Colors for Cards
  static List<Color> getCardGradientColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        darkSurfaceColor.withOpacity(0.9), // Daha yüksek opacity
        darkSurfaceColor.withOpacity(0.7), // Daha yüksek opacity
      ];
    } else {
      return [
        surfaceColor.withOpacity(0.8),
        surfaceColor.withOpacity(0.6),
      ];
    }
  }

  // Background Gradient Colors
  static List<Color> getBackgroundGradientColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        darkBackgroundColor,
        darkBackgroundColor.withOpacity(0.98), // Daha yüksek opacity
      ];
    } else {
      return [
        backgroundColor,
        backgroundColor.withOpacity(0.9),
      ];
    }
  }
}
