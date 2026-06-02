import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/image_reader/vertical_reader_gesture_controller.dart';

void main() {
  group('VerticalReaderGestureController', () {
    test(
      'pan returns the delta that remains after reaching a viewport edge',
      () {
        final controller = _createController();

        controller.zoomViewport(
          scaleFactor: 2,
          focalPoint: const Offset(150, 150),
          focalPointDelta: Offset.zero,
        );
        final unusedDelta = controller.panViewport(const Offset(200, -200));

        expect(controller.translation, const Offset(150, -150));
        expect(unusedDelta, const Offset(50, -50));
      },
    );

    test(
      'zoom preserves the content point beneath an off-center focal point',
      () {
        final controller = _createController();

        controller.zoomViewport(
          scaleFactor: 2,
          focalPoint: const Offset(225, 150),
          focalPointDelta: Offset.zero,
        );

        expect(controller.scale, 2);
        expect(controller.translation, const Offset(-75, 0));
      },
    );

    test('viewport resize clamps an existing translation', () {
      final controller = _createController();

      controller.zoomViewport(
        scaleFactor: 2,
        focalPoint: const Offset(150, 150),
        focalPointDelta: Offset.zero,
      );
      controller.panViewport(const Offset(150, 150));
      controller.configureViewport(const Size(100, 100));

      expect(controller.translation, const Offset(50, 50));
    });
  });
}

VerticalReaderGestureController _createController() {
  return VerticalReaderGestureController()
    ..configureViewport(const Size(300, 300));
}
