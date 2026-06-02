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

    test('pan availability changes when an image reaches its edge', () {
      final controller = _createSquareController();

      expect(controller.canPanImage(const Offset(-1, 0)), isFalse);

      controller.zoomImage(
        scaleFactor: 2,
        focalPoint: const Offset(150, 150),
        focalPointDelta: Offset.zero,
      );

      expect(controller.canPanImage(const Offset(-1, 0)), isTrue);

      controller.panImage(const Offset(-200, 0));

      expect(controller.translation, const Offset(-150, 0));
      expect(controller.canPanImage(const Offset(-1, 0)), isFalse);
      expect(controller.canPanImage(const Offset(1, 0)), isTrue);
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
    });
  });
}

PagedImageGestureController _createSquareController() {
  return PagedImageGestureController(initialPage: 0)
    ..configureViewport(viewportSize: const Size(300, 300), fit: BoxFit.contain)
    ..setIntrinsicImageSize(0, const Size(300, 300));
}
