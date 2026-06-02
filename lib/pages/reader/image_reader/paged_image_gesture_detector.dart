import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/pages/reader/image_reader/paged_image_gesture_controller.dart';

enum _PagedImageDragTarget { undecided, image, page }

class PagedImageGestureDetector extends HookWidget {
  static const double pageTurnThreshold = 0.18;
  static const double pageTurnVelocityThreshold = 650.0;

  final PageController pageController;
  final PagedImageGestureController gestureController;
  final int itemCount;
  final bool reverse;
  final BoxFit fit;
  final Widget child;

  const PagedImageGestureDetector({
    super.key,
    required this.pageController,
    required this.gestureController,
    required this.itemCount,
    required this.reverse,
    required this.fit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final gestureActive = useRef(false);
    final gestureIncludedPinch = useRef(false);
    final gestureSerial = useRef(0);
    final gesturePage = useRef(0);
    final lastPointerCount = useRef(0);
    final lastScale = useRef(1.0);
    final pageDragPixels = useRef(0.0);
    final centerPagePixels = useRef(0.0);
    final lastFocalPoint = useRef(Offset.zero);
    final dragTarget = useRef<_PagedImageDragTarget>(.undecided);
    final scheduledViewportSize = useRef<Size?>(null);
    final scheduledFit = useRef<BoxFit?>(null);

    void scheduleViewportConfiguration(Size viewportSize) {
      if (viewportSize.isEmpty ||
          !viewportSize.width.isFinite ||
          !viewportSize.height.isFinite ||
          (scheduledViewportSize.value == viewportSize &&
              scheduledFit.value == fit)) {
        return;
      }

      scheduledViewportSize.value = viewportSize;
      scheduledFit.value = fit;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;

        gestureController.configureViewport(
          viewportSize: viewportSize,
          fit: fit,
        );
      });
    }

    void cancelPageDrag() {
      if (!gestureActive.value || pageDragPixels.value == 0.0) return;

      if (pageController.hasClients) {
        pageController.jumpToPage(gesturePage.value);
        centerPagePixels.value = pageController.offset;
      }

      pageDragPixels.value = 0.0;
    }

    void dragPageBy(double visualDelta) {
      if (!pageController.hasClients || visualDelta == 0.0) return;

      final position = pageController.position;
      final viewportDimension = position.viewportDimension;
      final pixelDirection = reverse ? 1.0 : -1.0;
      final proposedPixels =
          centerPagePixels.value +
          (pageDragPixels.value + visualDelta) * pixelDirection;
      final minPixels = math.max(
        position.minScrollExtent,
        centerPagePixels.value - viewportDimension,
      );
      final maxPixels = math.min(
        position.maxScrollExtent,
        centerPagePixels.value + viewportDimension,
      );
      final nextPixels = proposedPixels.clamp(minPixels, maxPixels);

      pageDragPixels.value =
          (nextPixels - centerPagePixels.value) / pixelDirection;
      pageController.jumpTo(nextPixels);
    }

    int currentPage() {
      final page =
          pageController.page ?? gestureController.activePage.toDouble();
      return page.round().clamp(0, itemCount - 1);
    }

    int pageDeltaForVisualDrag(double visualDelta) {
      final pixelDirection = reverse ? 1.0 : -1.0;
      return (visualDelta * pixelDirection).sign.toInt();
    }

    _PagedImageDragTarget selectDragTarget(Offset delta) {
      if (delta.dx.abs() <= delta.dy.abs()) {
        return .image;
      }

      return gestureController.canPanImage(Offset(delta.dx, 0.0))
          ? .image
          : .page;
    }

    void handleScaleStart(ScaleStartDetails details) {
      if (!pageController.hasClients || itemCount == 0) return;

      gestureActive.value = true;
      gestureIncludedPinch.value = details.pointerCount >= 2;
      gestureSerial.value++;
      gesturePage.value = currentPage();
      lastPointerCount.value = details.pointerCount;
      lastScale.value = 1.0;
      lastFocalPoint.value = details.localFocalPoint;
      dragTarget.value = gestureIncludedPinch.value ? .image : .undecided;

      pageController.jumpToPage(gesturePage.value);
      centerPagePixels.value = pageController.offset;
      pageDragPixels.value = 0.0;
      gestureController.activatePage(gesturePage.value);
    }

    void handleScaleUpdate(ScaleUpdateDetails details) {
      if (!gestureActive.value) return;

      final focalPoint = details.localFocalPoint;
      final focalPointDelta = focalPoint - lastFocalPoint.value;

      if (details.pointerCount >= 2) {
        if (!gestureIncludedPinch.value) {
          gestureIncludedPinch.value = true;
          cancelPageDrag();
          dragTarget.value = .image;
        }

        if (lastPointerCount.value == details.pointerCount) {
          gestureController.zoomImage(
            scaleFactor: details.scale / lastScale.value,
            focalPoint: focalPoint,
            focalPointDelta: focalPointDelta,
          );
        }

        lastScale.value = details.scale;
        lastFocalPoint.value = focalPoint;
        lastPointerCount.value = details.pointerCount;
        return;
      }

      lastScale.value = details.scale;
      lastFocalPoint.value = focalPoint;
      lastPointerCount.value = details.pointerCount;

      if (gestureIncludedPinch.value) return;

      if (dragTarget.value == .undecided) {
        if (focalPointDelta == Offset.zero) return;

        dragTarget.value = selectDragTarget(focalPointDelta);
      }

      switch (dragTarget.value) {
        case .image:
          gestureController.panImage(focalPointDelta);
        case .page:
          dragPageBy(focalPointDelta.dx);
        case .undecided:
      }
    }

    Future<void> handleScaleEnd(ScaleEndDetails details) async {
      if (!gestureActive.value) return;

      gestureActive.value = false;
      final currentGestureSerial = gestureSerial.value;
      if (gestureIncludedPinch.value ||
          dragTarget.value != .page ||
          pageDragPixels.value == 0.0) {
        return;
      }

      final pageDragDirection = pageDragPixels.value.sign;
      final velocity = details.velocity.pixelsPerSecond.dx;
      final hasPageTurnVelocity =
          velocity.sign == pageDragDirection &&
          velocity.abs() >= pageTurnVelocityThreshold;
      final hasPageTurnDistance =
          pageDragPixels.value.abs() >=
          gestureController.viewportSize.width * pageTurnThreshold;
      final pageDelta = pageDeltaForVisualDrag(pageDragPixels.value);
      final targetPage = hasPageTurnDistance || hasPageTurnVelocity
          ? (gesturePage.value + pageDelta).clamp(0, itemCount - 1)
          : gesturePage.value;

      pageDragPixels.value = 0.0;

      if (pageController.hasClients) {
        await pageController.animateToPage(
          targetPage,
          duration: 200.ms,
          curve: Curves.easeInOut,
        );
      }

      if (!context.mounted ||
          currentGestureSerial != gestureSerial.value ||
          targetPage == gesturePage.value) {
        return;
      }

      gestureController.resetForPage(targetPage);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        scheduleViewportConfiguration(constraints.biggest);

        return GestureDetector(
          behavior: .opaque,
          onScaleStart: handleScaleStart,
          onScaleUpdate: handleScaleUpdate,
          onScaleEnd: (details) => unawaited(handleScaleEnd(details)),
          child: child,
        );
      },
    );
  }
}
