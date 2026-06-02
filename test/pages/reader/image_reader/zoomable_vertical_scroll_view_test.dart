import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/image_reader/vertical_reader_gesture_controller.dart';
import 'package:kover/pages/reader/image_reader/zoomable_vertical_scroll_view.dart';

void main() {
  testWidgets('base-scale vertical drag scrolls the continuous list', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final gestureController = VerticalReaderGestureController();
    addTearDown(scrollController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildScrollView(
        scrollController: scrollController,
        gestureController: gestureController,
      ),
    );
    await tester.pump();

    await tester.timedDrag(
      find.byType(ZoomableVerticalScrollView),
      const Offset(0, -100),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(0));
    expect(gestureController.translation, Offset.zero);
  });

  testWidgets('zoomed vertical drag pans before scrolling the list', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final gestureController = VerticalReaderGestureController();
    addTearDown(scrollController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildScrollView(
        scrollController: scrollController,
        gestureController: gestureController,
      ),
    );
    await tester.pump();
    gestureController.zoomViewport(
      scaleFactor: 2,
      focalPoint: const Offset(150, 150),
      focalPointDelta: Offset.zero,
    );

    await tester.timedDrag(
      find.byType(ZoomableVerticalScrollView),
      const Offset(0, -100),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, 0);
    expect(gestureController.translation.dy, -100);
  });

  testWidgets('zoomed viewport hands unused edge drag to list scrolling', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final gestureController = VerticalReaderGestureController();
    addTearDown(scrollController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildScrollView(
        scrollController: scrollController,
        gestureController: gestureController,
      ),
    );
    await tester.pump();
    gestureController
      ..zoomViewport(
        scaleFactor: 2,
        focalPoint: const Offset(150, 150),
        focalPointDelta: Offset.zero,
      )
      ..panViewport(const Offset(0, -150));

    await tester.timedDrag(
      find.byType(ZoomableVerticalScrollView),
      const Offset(0, -100),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(0));
    expect(gestureController.translation.dy, -150);
  });

  testWidgets('pinch sequence cannot scroll after one pointer lifts', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final gestureController = VerticalReaderGestureController();
    addTearDown(scrollController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildScrollView(
        scrollController: scrollController,
        gestureController: gestureController,
      ),
    );
    await tester.pump();
    final firstPointer = await tester.startGesture(const Offset(100, 150));
    final secondPointer = await tester.startGesture(const Offset(200, 150));

    await firstPointer.moveTo(const Offset(50, 150));
    await secondPointer.moveTo(const Offset(250, 150));
    await tester.pump();
    await secondPointer.up();
    await firstPointer.moveBy(const Offset(0, -200));
    await tester.pump();
    await firstPointer.up();
    await tester.pumpAndSettle();

    expect(gestureController.scale, greaterThan(1));
    expect(scrollController.offset, 0);
  });
}

Widget _buildScrollView({
  required ScrollController scrollController,
  required VerticalReaderGestureController gestureController,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          height: 300,
          child: ZoomableVerticalScrollView(
            scrollController: scrollController,
            gestureController: gestureController,
            child: ListView(
              controller: scrollController,
              children: List.generate(
                10,
                (index) => const SizedBox(height: 100),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
