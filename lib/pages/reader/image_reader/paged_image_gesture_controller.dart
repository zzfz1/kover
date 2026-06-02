import 'dart:math' as math;

import 'package:flutter/material.dart';

class PagedImageGestureController extends ChangeNotifier {
  final double minScale;
  final double maxScale;

  PagedImageGestureController({
    required int initialPage,
    this.minScale = 1.0,
    this.maxScale = 4.0,
  }) : assert(minScale > 0),
       assert(maxScale >= minScale),
       _activePage = initialPage,
       _scale = minScale;

  final Map<int, Size> _intrinsicImageSizes = {};

  int _activePage;
  Size _viewportSize = Size.zero;
  BoxFit _fit = BoxFit.contain;
  double _scale;
  Offset _translation = Offset.zero;

  int get activePage => _activePage;
  Size get viewportSize => _viewportSize;
  double get scale => _scale;
  Offset get translation => _translation;

  Size get fittedImageSize {
    final intrinsicSize = _intrinsicImageSizes[_activePage];
    if (intrinsicSize == null) return Size.zero;

    return calculateFittedImageSize(
      intrinsicSize: intrinsicSize,
      viewportSize: _viewportSize,
      fit: _fit,
    );
  }

  static Size calculateFittedImageSize({
    required Size intrinsicSize,
    required Size viewportSize,
    required BoxFit fit,
  }) {
    final fittedSizes = applyBoxFit(fit, intrinsicSize, viewportSize);
    if (fittedSizes.source.isEmpty || fittedSizes.destination.isEmpty) {
      return Size.zero;
    }

    final scale = fittedSizes.destination.width / fittedSizes.source.width;
    return Size(intrinsicSize.width * scale, intrinsicSize.height * scale);
  }

  void configureViewport({required Size viewportSize, required BoxFit fit}) {
    if (_viewportSize == viewportSize && _fit == fit) return;

    _viewportSize = viewportSize;
    _fit = fit;
    _clampTranslation();
    notifyListeners();
  }

  void setIntrinsicImageSize(int page, Size size) {
    if (_intrinsicImageSizes[page] == size) return;

    _intrinsicImageSizes[page] = size;
    if (page == _activePage) {
      _clampTranslation();
      notifyListeners();
    }
  }

  void activatePage(int page) {
    if (_activePage == page) return;

    _activePage = page;
    _clampTranslation();
    notifyListeners();
  }

  void resetForPage(int page) {
    final changed =
        _activePage != page ||
        _scale != minScale ||
        _translation != Offset.zero;

    _activePage = page;
    _scale = minScale;
    _translation = Offset.zero;

    if (changed) {
      notifyListeners();
    }
  }

  bool canPanImage(Offset delta) {
    return _clampOffset(_translation + delta) != _translation;
  }

  void panImage(Offset delta) {
    final nextTranslation = _clampOffset(_translation + delta);
    if (nextTranslation == _translation) return;

    _translation = nextTranslation;
    notifyListeners();
  }

  void zoomImage({
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
    final imageSize = fittedImageSize;
    final effectiveScale = scale ?? _scale;
    final overflowX = math.max(
      0.0,
      (imageSize.width * effectiveScale - _viewportSize.width) / 2,
    );
    final overflowY = math.max(
      0.0,
      (imageSize.height * effectiveScale - _viewportSize.height) / 2,
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
