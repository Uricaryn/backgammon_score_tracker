import 'package:flutter/material.dart';
import 'dart:math' as math;

class DiceSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;
  final Duration duration;

  const DiceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 60.0,
    this.height = 30.0,
    this.activeColor,
    this.inactiveColor,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<DiceSwitch> createState() => _DiceSwitchState();
}

class _DiceSwitchState extends State<DiceSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _bounceAnimation;
  int _currentDiceFace = 6; // Start with 6
  int _targetDiceFace = 1; // Target is 1

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0, // Full rotation (720 degrees)
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    if (widget.value) {
      _animationController.value = 1.0;
      _currentDiceFace = 6; // System theme enabled = 6
    } else {
      _currentDiceFace = 1; // System theme disabled = 1
    }
  }

  @override
  void didUpdateWidget(DiceSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _targetDiceFace = 6; // System theme enabled = 6
        _animationController.forward();
      } else {
        _targetDiceFace = 1; // System theme disabled = 1
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveColor = widget.inactiveColor ?? theme.colorScheme.outline;

    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height / 2),
              color:
                  Color.lerp(inactiveColor, activeColor, _slideAnimation.value),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Dice container
                Positioned(
                  left: _slideAnimation.value * (widget.width - widget.height),
                  top: 0,
                  child: Transform.scale(
                    scale: 0.8 + (_bounceAnimation.value * 0.2),
                    child: Container(
                      width: widget.height,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color:
                            isDark ? theme.colorScheme.surface : Colors.white,
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: _rotationAnimation.value * math.pi,
                          child: _buildDiceFace(_getCurrentDiceFace()),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _getCurrentDiceFace() {
    // Interpolate between dice faces during animation
    if (_animationController.value < 0.5) {
      return _currentDiceFace;
    } else {
      return _targetDiceFace;
    }
  }

  Widget _buildDiceFace(int face) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: widget.height * 0.6,
      height: widget.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? theme.colorScheme.outline : Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: Stack(
        children: _getDiceDots(face),
      ),
    );
  }

  List<Widget> _getDiceDots(int face) {
    final dots = <Widget>[];
    final dotSize = 3.0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dotColor = isDark ? theme.colorScheme.onSurface : Colors.black;

    switch (face) {
      case 1:
        // Center dot
        dots.add(
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(dotSize / 2),
                ),
              ),
            ),
          ),
        );
        break;
      case 2:
        // Top-left and bottom-right
        dots.addAll([
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
        ]);
        break;
      case 3:
        // Top-left, center, bottom-right
        dots.addAll([
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(dotSize / 2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
        ]);
        break;
      case 4:
        // All four corners
        dots.addAll([
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            left: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
        ]);
        break;
      case 5:
        // All four corners + center
        dots.addAll([
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(dotSize / 2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            left: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
        ]);
        break;
      case 6:
        // Two rows of three dots
        dots.addAll([
          // Top row
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(dotSize / 2),
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          // Bottom row
          Positioned(
            bottom: 2,
            left: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(dotSize / 2),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(dotSize / 2),
              ),
            ),
          ),
        ]);
        break;
    }

    return dots;
  }
}
