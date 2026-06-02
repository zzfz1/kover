import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/image_reader/paged_image_gesture_controller.dart';

void main() {
  group('PagedImageGestureController', () {
    test('fit width retains vertical overflow outside the viewport', () {
      final size = PagedImageGestureController.calculateFittedImageSize(
        intrinsicSize: const Size(100, 300),
        viewportSize: const Size(300, 100),
        fit: BoxFit.fitWidth,
      );

      expect(size, const Size(300, 900));
    });

    test('fit height retains horizontal overflow outside the viewport', () {
      final size = PagedImageGestureController.calculateFittedImageSize(
        intrinsicSize: const Size(300, 100),
        viewportSize: const Size(100, 300),
        fit: BoxFit.fitHeight,
      );

      expect(size, const Size(900, 300));
    });

    test('pan returns the delta that remains after reaching an image edge', () {
      final controller = _createSquareController();

      controller.zoomImage(
        scaleFactor: 2,
        focalPoint: const Offset(150, 150),
        focalPointDelta: Offset.zero,
      );
      final unusedDelta = controller.panImage(const Offset(200, 0));

      expect(controller.translation, const Offset(150, 0));
      expect(unusedDelta, const Offset(50, 0));
    });

    test('base fit-width image can be panned over its vertical overflow', () {
      final controller = PagedImageGestureController(initialPage: 0)
        ..configureViewport(
          viewportSize: const Size(300, 100),
          fit: BoxFit.fitWidth,
        )
        ..setIntrinsicImageSize(0, const Size(100, 300));

      final unusedDelta = controller.panImage(const Offset(0, -500));

      expect(controller.translation, const Offset(0, -400));
      expect(unusedDelta, const Offset(0, -100));
    });

    test(
      'zoom preserves the image point beneath an off-center focal point',
      () {
        final controller = _createSquareController();

        controller.zoomImage(
          scaleFactor: 2,
          focalPoint: const Offset(225, 150),
          focalPointDelta: Offset.zero,
        );

        expect(controller.scale, 2);
        expect(controller.translation, const Offset(-75, 0));
      },
    );

    test('resetting for a new page clears zoom and translation', () {
      final controller = _createSquareController();

      controller.zoomImage(
        scaleFactor: 2,
        focalPoint: const Offset(150, 150),
        focalPointDelta: Offset.zero,
      );
      controller.panImage(const Offset(75, 50));
      controller.resetForPage(1);

      expect(controller.activePage, 1);
      expect(controller.scale, 1);
      expect(controller.translation, Offset.zero);
      expect(controller.mode, PagedImageGestureMode.idle);
    });

    test('viewport resize clamps an existing translation', () {
      final controller = _createSquareController();

      controller.zoomImage(
        scaleFactor: 2,
        focalPoint: const Offset(150, 150),
        focalPointDelta: Offset.zero,
      );
      controller.panImage(const Offset(150, 150));
      controller.configureViewport(
        viewportSize: const Size(500, 500),
        fit: BoxFit.contain,
      );

      expect(controller.translation, const Offset(150, 150));
      controller.configureViewport(
        viewportSize: const Size(100, 100),
        fit: BoxFit.contain,
      );
      expect(controller.translation, const Offset(50, 50));
    });
  });
}

PagedImageGestureController _createSquareController() {
  return PagedImageGestureController(initialPage: 0)
    ..configureViewport(viewportSize: const Size(300, 300), fit: BoxFit.contain)
    ..setIntrinsicImageSize(0, const Size(300, 300));
}
