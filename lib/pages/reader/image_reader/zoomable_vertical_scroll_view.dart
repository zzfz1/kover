import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kover/pages/reader/image_reader/vertical_reader_gesture_controller.dart';

class ZoomableVerticalScrollView extends StatefulWidget {
  final ScrollController scrollController;
  final VerticalReaderGestureController gestureController;
  final Widget child;

  const ZoomableVerticalScrollView({
    super.key,
    required this.scrollController,
    required this.gestureController,
    required this.child,
  });

  @override
  State<ZoomableVerticalScrollView> createState() =>
      _ZoomableVerticalScrollViewState();
}

class _ZoomableVerticalScrollViewState
    extends State<ZoomableVerticalScrollView> {
  bool _gestureActive = false;
  bool _gestureIncludedPinch = false;
  bool _scrolledDuringGesture = false;
  int _lastPointerCount = 0;
  double _lastScale = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  Size? _scheduledViewportSize;

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
          child: ClipRect(
            child: AnimatedBuilder(
              animation: widget.gestureController,
              child: IgnorePointer(child: widget.child),
              builder: (context, child) {
                return Transform.translate(
                  offset: widget.gestureController.translation,
                  child: Transform.scale(
                    scale: widget.gestureController.scale,
                    child: child,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _scheduleViewportConfiguration(Size viewportSize) {
    if (viewportSize.isEmpty ||
        !viewportSize.width.isFinite ||
        !viewportSize.height.isFinite ||
        _scheduledViewportSize == viewportSize) {
      return;
    }

    _scheduledViewportSize = viewportSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      widget.gestureController.configureViewport(viewportSize);
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _gestureActive = true;
    _gestureIncludedPinch = details.pointerCount >= 2;
    _scrolledDuringGesture = false;
    _lastPointerCount = details.pointerCount;
    _lastScale = 1.0;
    _lastFocalPoint = details.localFocalPoint;

    if (widget.scrollController.hasClients) {
      final position = widget.scrollController.position;
      position.jumpTo(position.pixels);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!_gestureActive) return;

    final focalPoint = details.localFocalPoint;
    final focalPointDelta = focalPoint - _lastFocalPoint;

    if (details.pointerCount >= 2) {
      _gestureIncludedPinch = true;
      if (_lastPointerCount == details.pointerCount) {
        widget.gestureController.zoomViewport(
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

    final unusedDelta = widget.gestureController.panViewport(focalPointDelta);
    _scrollByVisualDelta(unusedDelta.dy);
  }

  Future<void> _handleScaleEnd(ScaleEndDetails details) async {
    if (!_gestureActive) return;

    _gestureActive = false;
    if (_gestureIncludedPinch ||
        !_scrolledDuringGesture ||
        !widget.scrollController.hasClients) {
      return;
    }

    final position = widget.scrollController.position;
    if (position is ScrollPositionWithSingleContext) {
      position.goBallistic(
        -details.velocity.pixelsPerSecond.dy / widget.gestureController.scale,
      );
    }
  }

  void _scrollByVisualDelta(double visualDelta) {
    if (visualDelta == 0.0 || !widget.scrollController.hasClients) return;

    final position = widget.scrollController.position;
    final nextPixels =
        (position.pixels - visualDelta / widget.gestureController.scale).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    if (nextPixels == position.pixels) return;

    _scrolledDuringGesture = true;
    position.jumpTo(nextPixels);
  }
}
