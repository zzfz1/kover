import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kover/pages/reader/image_reader/paged_image_gesture_controller.dart';

class SeamlessPagedView extends StatefulWidget {
  static const double pageTurnThreshold = 0.18;
  static const double pageTurnVelocityThreshold = 650.0;

  final PageController pageController;
  final PagedImageGestureController gestureController;
  final int itemCount;
  final bool reverse;
  final BoxFit fit;
  final Widget child;

  const SeamlessPagedView({
    super.key,
    required this.pageController,
    required this.gestureController,
    required this.itemCount,
    required this.reverse,
    required this.fit,
    required this.child,
  });

  @override
  State<SeamlessPagedView> createState() => _SeamlessPagedViewState();
}

class _SeamlessPagedViewState extends State<SeamlessPagedView> {
  bool _gestureActive = false;
  bool _gestureIncludedPinch = false;
  int _gestureSerial = 0;
  int _gesturePage = 0;
  int _lastPointerCount = 0;
  double _lastScale = 1.0;
  double _pageDragPixels = 0.0;
  double _centerPagePixels = 0.0;
  Offset _lastFocalPoint = Offset.zero;
  Size? _scheduledViewportSize;
  BoxFit? _scheduledFit;

  @override
  void didUpdateWidget(SeamlessPagedView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.reverse != oldWidget.reverse ||
        widget.pageController != oldWidget.pageController) {
      _cancelPageDrag();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleViewportConfiguration(constraints.biggest);

        return GestureDetector(
          behavior: .opaque,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: (details) => unawaited(_handleScaleEnd(details)),
          child: widget.child,
        );
      },
    );
  }

  void _scheduleViewportConfiguration(Size viewportSize) {
    if (viewportSize.isEmpty ||
        !viewportSize.width.isFinite ||
        !viewportSize.height.isFinite ||
        (_scheduledViewportSize == viewportSize &&
            _scheduledFit == widget.fit)) {
      return;
    }

    _scheduledViewportSize = viewportSize;
    _scheduledFit = widget.fit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      widget.gestureController.configureViewport(
        viewportSize: viewportSize,
        fit: widget.fit,
      );
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (!widget.pageController.hasClients || widget.itemCount == 0) return;

    _gestureActive = true;
    _gestureIncludedPinch = details.pointerCount >= 2;
    _gestureSerial++;
    _gesturePage = _currentPage;
    _lastPointerCount = details.pointerCount;
    _lastScale = 1.0;
    _lastFocalPoint = details.localFocalPoint;

    widget.pageController.jumpToPage(_gesturePage);
    _centerPagePixels = widget.pageController.offset;
    _pageDragPixels = 0.0;

    widget.gestureController.activatePage(_gesturePage);
    widget.gestureController.startGesture();
    if (_gestureIncludedPinch) {
      widget.gestureController.startPinch();
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!_gestureActive) return;

    final focalPoint = details.localFocalPoint;
    final focalPointDelta = focalPoint - _lastFocalPoint;

    if (details.pointerCount >= 2) {
      if (!_gestureIncludedPinch) {
        _gestureIncludedPinch = true;
        _cancelPageDrag();
        widget.gestureController.startPinch();
      }

      if (_lastPointerCount == details.pointerCount) {
        widget.gestureController.zoomImage(
          scaleFactor: details.scale / _lastScale,
          focalPoint: focalPoint,
          focalPointDelta: focalPointDelta,
        );
      }

      _lastScale = details.scale;
      _lastFocalPoint = focalPoint;
      _lastPointerCount = details.pointerCount;
      return;
    }

    _lastScale = details.scale;
    _lastFocalPoint = focalPoint;
    _lastPointerCount = details.pointerCount;

    if (_gestureIncludedPinch) return;

    _handleSinglePointerDelta(focalPointDelta);
  }

  Future<void> _handleScaleEnd(ScaleEndDetails details) async {
    if (!_gestureActive) return;

    _gestureActive = false;
    final gestureSerial = _gestureSerial;
    if (_gestureIncludedPinch || _pageDragPixels == 0.0) {
      widget.gestureController.endGesture();
      return;
    }

    final pageDragDirection = _pageDragPixels.sign;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final hasPageTurnVelocity =
        velocity.sign == pageDragDirection &&
        velocity.abs() >= SeamlessPagedView.pageTurnVelocityThreshold;
    final hasPageTurnDistance =
        _pageDragPixels.abs() >=
        widget.gestureController.viewportSize.width *
            SeamlessPagedView.pageTurnThreshold;
    final pageDelta = _pageDeltaForVisualDrag(_pageDragPixels);
    final targetPage = hasPageTurnDistance || hasPageTurnVelocity
        ? (_gesturePage + pageDelta).clamp(0, widget.itemCount - 1)
        : _gesturePage;

    _pageDragPixels = 0.0;
    widget.gestureController.endGesture();

    if (widget.pageController.hasClients) {
      await widget.pageController.animateToPage(
        targetPage,
        duration: 200.ms,
        curve: Curves.easeInOut,
      );
    }

    if (!mounted ||
        gestureSerial != _gestureSerial ||
        targetPage == _gesturePage) {
      return;
    }

    widget.gestureController.resetForPage(targetPage);
  }

  void _handleSinglePointerDelta(Offset delta) {
    widget.gestureController.panImage(Offset(0.0, delta.dy));

    var horizontalDelta = delta.dx;
    if (_pageDragPixels != 0.0) {
      if (horizontalDelta.sign == _pageDragPixels.sign) {
        _dragPageBy(horizontalDelta);
        return;
      }

      final retraction = math.min(horizontalDelta.abs(), _pageDragPixels.abs());
      final retractionDelta = horizontalDelta.sign * retraction;
      _dragPageBy(retractionDelta);
      horizontalDelta -= retractionDelta;
    }

    if (horizontalDelta == 0.0) return;

    final unusedDelta = widget.gestureController.panImage(
      Offset(horizontalDelta, 0.0),
    );
    if (unusedDelta.dx != 0.0) {
      _dragPageBy(unusedDelta.dx);
    }
  }

  void _dragPageBy(double visualDelta) {
    if (!widget.pageController.hasClients || visualDelta == 0.0) return;

    final position = widget.pageController.position;
    final viewportDimension = position.viewportDimension;
    final pixelDirection = widget.reverse ? 1.0 : -1.0;
    final proposedPixels =
        _centerPagePixels + (_pageDragPixels + visualDelta) * pixelDirection;
    final minPixels = math.max(
      position.minScrollExtent,
      _centerPagePixels - viewportDimension,
    );
    final maxPixels = math.min(
      position.maxScrollExtent,
      _centerPagePixels + viewportDimension,
    );
    final nextPixels = proposedPixels.clamp(minPixels, maxPixels);

    _pageDragPixels = (nextPixels - _centerPagePixels) / pixelDirection;
    widget.gestureController.startPageDrag();
    widget.pageController.jumpTo(nextPixels);
  }

  void _cancelPageDrag() {
    if (!_gestureActive || _pageDragPixels == 0.0) return;

    if (widget.pageController.hasClients) {
      widget.pageController.jumpToPage(_gesturePage);
      _centerPagePixels = widget.pageController.offset;
    }

    _pageDragPixels = 0.0;
  }

  int _pageDeltaForVisualDrag(double visualDelta) {
    final pixelDirection = widget.reverse ? 1.0 : -1.0;
    return (visualDelta * pixelDirection).sign.toInt();
  }

  int get _currentPage {
    final page =
        widget.pageController.page ??
        widget.gestureController.activePage.toDouble();
    return page.round().clamp(0, widget.itemCount - 1);
  }
}
