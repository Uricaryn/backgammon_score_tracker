import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Loads optional checker sprite PNGs; gradient painting is used when missing.
class BoardAssetsService {
  BoardAssetsService._();
  static final BoardAssetsService instance = BoardAssetsService._();

  ui.Image? _whiteChecker;
  ui.Image? _blackChecker;
  bool _initStarted = false;
  bool _ready = false;

  bool get hasCheckerSprites =>
      _ready && _whiteChecker != null && _blackChecker != null;

  Future<void> ensureLoaded() async {
    if (_initStarted) return;
    _initStarted = true;
    _whiteChecker = await _loadImage('assets/sprites/checkers/checker_white.png');
    _blackChecker = await _loadImage('assets/sprites/checkers/checker_black.png');
    _ready = true;
  }

  ui.Image? checkerImage(bool white) => white ? _whiteChecker : _blackChecker;

  static Future<ui.Image?> _loadImage(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}
