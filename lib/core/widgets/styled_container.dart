import 'package:flutter/material.dart';

class StyledContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;

  const StyledContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 12.0,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ??
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: borderWidth!,
        ),
      ),
      child: child,
    );
  }
}
