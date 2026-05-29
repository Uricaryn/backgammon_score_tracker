import 'package:flutter/material.dart';

class AppThemeExtensions extends ThemeExtension<AppThemeExtensions> {
  const AppThemeExtensions({
    required this.premiumAccent,
    required this.premiumAccentContainer,
  });

  final Color premiumAccent;
  final Color premiumAccentContainer;

  static const light = AppThemeExtensions(
    premiumAccent: Color(0xFFF9A825),
    premiumAccentContainer: Color(0xFFFFF8E1),
  );

  static const dark = AppThemeExtensions(
    premiumAccent: Color(0xFFFFCA28),
    premiumAccentContainer: Color(0xFF3E2723),
  );

  @override
  AppThemeExtensions copyWith({
    Color? premiumAccent,
    Color? premiumAccentContainer,
  }) {
    return AppThemeExtensions(
      premiumAccent: premiumAccent ?? this.premiumAccent,
      premiumAccentContainer:
          premiumAccentContainer ?? this.premiumAccentContainer,
    );
  }

  @override
  AppThemeExtensions lerp(
    ThemeExtension<AppThemeExtensions>? other,
    double t,
  ) {
    if (other is! AppThemeExtensions) return this;
    return AppThemeExtensions(
      premiumAccent: Color.lerp(premiumAccent, other.premiumAccent, t)!,
      premiumAccentContainer: Color.lerp(
        premiumAccentContainer,
        other.premiumAccentContainer,
        t,
      )!,
    );
  }
}

extension AppThemeExtensionsContext on BuildContext {
  AppThemeExtensions get appThemeExtensions =>
      Theme.of(this).extension<AppThemeExtensions>() ??
      AppThemeExtensions.light;
}
