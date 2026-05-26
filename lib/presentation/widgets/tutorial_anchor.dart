import 'package:flutter/material.dart';

/// Tutorial spotlight için sabit sınırlı hedef; [GlobalKey] doğrudan karta bağlanır.
class TutorialAnchor extends StatelessWidget {
  const TutorialAnchor({
    super.key,
    required this.anchorKey,
    required this.child,
    this.fullWidth = true,
  });

  final GlobalKey anchorKey;
  final Widget child;

  /// Kartlar için true; FAB gibi kompakt widget'lar için false.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: anchorKey,
      child: fullWidth
          ? SizedBox(width: double.infinity, child: child)
          : child,
    );
  }
}
