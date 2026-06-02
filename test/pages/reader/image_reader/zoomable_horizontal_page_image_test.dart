import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/image_reader/paged_image_gesture_controller.dart';
import 'package:kover/pages/reader/image_reader/zoomable_horizontal_page_image.dart';

void main() {
  testWidgets('reports the intrinsic image size to the gesture controller', (
    tester,
  ) async {
    final controller = PagedImageGestureController(initialPage: 0)
      ..configureViewport(
        viewportSize: const Size(100, 100),
        fit: BoxFit.contain,
      );
    addTearDown(controller.dispose);
    final data = File('assets/icon/icon.png').readAsBytesSync();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 100,
          child: ZoomableHorizontalPageImage(
            data,
            page: 0,
            fit: BoxFit.contain,
            controller: controller,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        MemoryImage(data),
        tester.element(find.byType(ZoomableHorizontalPageImage)),
      );
    });
    await tester.pumpAndSettle();

    expect(controller.fittedImageSize, const Size(100, 100));
  });
}
