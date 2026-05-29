import 'package:flutter/material.dart';

/// Subtle vignette + sheen so the board reads as a distinct “table” surface.
class BoardAmbienceOverlay extends StatelessWidget {
  const BoardAmbienceOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: RadialGradient(
            center: const Alignment(0, -0.1),
            radius: 1.05,
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.35),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
