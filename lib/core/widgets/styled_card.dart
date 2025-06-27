import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:backgammon_score_tracker/core/theme/app_theme.dart';

class StyledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool useBackdropFilter;

  const StyledCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0,
    this.useBackdropFilter = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.getCardGradientColors(context),
          ),
          border: Border.all(
            color: isDark
                ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: isDark ? 1.5 : 1.0,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: useBackdropFilter
              ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: isDark ? 15 : 10,
                    sigmaY: isDark ? 15 : 10,
                  ),
                  child: Padding(
                    padding: padding ?? const EdgeInsets.all(20.0),
                    child: child,
                  ),
                )
              : Padding(
                  padding: padding ?? const EdgeInsets.all(20.0),
                  child: child,
                ),
        ),
      ),
    );
  }
}
