import 'dart:math' as math;

import 'package:flutter/material.dart';

class VerticalReaderGestureController extends ChangeNotifier {
  final double minScale;
  final double maxScale;

  VerticalReaderGestureController({
    this.minScale = 1.0,
    this.maxScale = 4.0,
  }) : assert(minScale > 0),
       assert(maxScale >= minScale),
       _scale = minScale;

  Size _viewportSize = Size.zero;
  double _scale;
  Offset _translation = Offset.zero;

  Size get viewportSize => _viewportSize;
  double get scale => _scale;
  Offset get translation => _translation;
  bool get isZoomed => _scale > minScale;

  Size get panOverflow => Size(
    math.max(0.0, (_viewportSize.width * _scale - _viewportSize.width) / 2),
    math.max(0.0, (_viewportSize.height * _scale - _viewportSize.height) / 2),
  );

  void configureViewport(Size viewportSize) {
    if (_viewportSize == viewportSize) return;

    _viewportSize = viewportSize;
    _clampTranslation();
    notifyListeners();
  }

  Offset panViewport(Offset delta) {
    final attemptedTranslation = _translation + delta;
    final nextTranslation = _clampOffset(attemptedTranslation);
    if (nextTranslation != _translation) {
      _translation = nextTranslation;
      notifyListeners();
    }

    return attemptedTranslation - nextTranslation;
  }

  void zoomViewport({
    required double scaleFactor,
    required Offset focalPoint,
    required Offset focalPointDelta,
  }) {
    if (!scaleFactor.isFinite || scaleFactor <= 0) return;

    final nextScale = (_scale * scaleFactor).clamp(minScale, maxScale);
    final appliedFactor = nextScale / _scale;
    final previousFocalPoint = focalPoint - focalPointDelta;
    final focalPointFromCenter =
        previousFocalPoint - _viewportSize.center(Offset.zero);
    final nextTranslation = _clampOffset(
      focalPointDelta +
          _translation * appliedFactor +
          focalPointFromCenter * (1 - appliedFactor),
      scale: nextScale,
    );

    if (_scale == nextScale && _translation == nextTranslation) return;

    _scale = nextScale;
    _translation = nextTranslation;
    notifyListeners();
  }

  Offset _clampOffset(Offset offset, {double? scale}) {
    final effectiveScale = scale ?? _scale;
    final overflowX = math.max(
      0.0,
      (_viewportSize.width * effectiveScale - _viewportSize.width) / 2,
    );
    final overflowY = math.max(
      0.0,
      (_viewportSize.height * effectiveScale - _viewportSize.height) / 2,
    );

    return Offset(
      offset.dx.clamp(-overflowX, overflowX),
      offset.dy.clamp(-overflowY, overflowY),
    );
  }

  void _clampTranslation() {
    _translation = _clampOffset(_translation);
  }
}
