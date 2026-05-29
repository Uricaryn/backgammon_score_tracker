import 'package:flutter/material.dart';

/// Whether reduced motion is requested (accessibility).
bool boardAnimationsEnabled(BuildContext context) {
  return !MediaQuery.of(context).disableAnimations;
}
