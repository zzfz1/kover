import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kover/pages/reader/image_reader/paged_image_gesture_controller.dart';
import 'package:kover/pages/reader/image_reader/seamless_paged_view.dart';

void main() {
  testWidgets('unzoomed drag above threshold turns one page', (tester) async {
    final pageController = PageController();
    final gestureController = PagedImageGestureController(initialPage: 0);
    addTearDown(pageController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildPagedView(
        pageController: pageController,
        gestureController: gestureController,
      ),
    );
    await tester.pump();

    await tester.timedDrag(
      find.byType(SeamlessPagedView),
      const Offset(-100, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(pageController.page, 1);
  });

  testWidgets('unzoomed drag below threshold snaps back', (tester) async {
    final pageController = PageController();
    final gestureController = PagedImageGestureController(initialPage: 0);
    addTearDown(pageController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildPagedView(
        pageController: pageController,
        gestureController: gestureController,
      ),
    );
    await tester.pump();

    await tester.timedDrag(
      find.byType(SeamlessPagedView),
      const Offset(-30, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(pageController.page, 0);
  });

  testWidgets('zoomed image hands unused edge drag to the page view', (
    tester,
  ) async {
    final pageController = PageController();
    final gestureController = PagedImageGestureController(initialPage: 0);
    addTearDown(pageController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildPagedView(
        pageController: pageController,
        gestureController: gestureController,
      ),
    );
    await tester.pump();
    gestureController
      ..setIntrinsicImageSize(0, const Size(300, 300))
      ..zoomImage(
        scaleFactor: 2,
        focalPoint: const Offset(150, 150),
        focalPointDelta: Offset.zero,
      )
      ..panImage(const Offset(-150, 0));

    await tester.timedDrag(
      find.byType(SeamlessPagedView),
      const Offset(-100, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(pageController.page, 1);
    expect(gestureController.activePage, 1);
    expect(gestureController.scale, 1);
    expect(gestureController.translation, Offset.zero);
  });

  testWidgets('rtl outward drag turns the correct logical page', (
    tester,
  ) async {
    final pageController = PageController(initialPage: 1);
    final gestureController = PagedImageGestureController(initialPage: 1);
    addTearDown(pageController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildPagedView(
        pageController: pageController,
        gestureController: gestureController,
        reverse: true,
      ),
    );
    await tester.pump();

    await tester.timedDrag(
      find.byType(SeamlessPagedView),
      const Offset(100, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(pageController.page, 2);
  });

  testWidgets('outward drag at terminal page does not overrun bounds', (
    tester,
  ) async {
    final pageController = PageController();
    final gestureController = PagedImageGestureController(initialPage: 0);
    addTearDown(pageController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildPagedView(
        pageController: pageController,
        gestureController: gestureController,
      ),
    );
    await tester.pump();

    await tester.timedDrag(
      find.byType(SeamlessPagedView),
      const Offset(100, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(pageController.page, 0);
  });

  testWidgets('pinch sequence cannot turn a page after one pointer lifts', (
    tester,
  ) async {
    final pageController = PageController();
    final gestureController = PagedImageGestureController(initialPage: 0);
    addTearDown(pageController.dispose);
    addTearDown(gestureController.dispose);
    await tester.pumpWidget(
      _buildPagedView(
        pageController: pageController,
        gestureController: gestureController,
      ),
    );
    await tester.pump();
    gestureController.setIntrinsicImageSize(0, const Size(300, 300));
    final firstPointer = await tester.startGesture(const Offset(100, 150));
    final secondPointer = await tester.startGesture(const Offset(200, 150));

    await firstPointer.moveTo(const Offset(50, 150));
    await secondPointer.moveTo(const Offset(250, 150));
    await tester.pump();
    await secondPointer.up();
    await firstPointer.moveBy(const Offset(-200, 0));
    await tester.pump();
    await firstPointer.up();
    await tester.pumpAndSettle();

    expect(gestureController.scale, greaterThan(1));
    expect(pageController.page, 0);
  });
}

Widget _buildPagedView({
  required PageController pageController,
  required PagedImageGestureController gestureController,
  bool reverse = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          height: 300,
          child: SeamlessPagedView(
            pageController: pageController,
            gestureController: gestureController,
            itemCount: 3,
            reverse: reverse,
            fit: BoxFit.contain,
            child: PageView(
              controller: pageController,
              reverse: reverse,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                ColoredBox(color: Colors.red),
                ColoredBox(color: Colors.green),
                ColoredBox(color: Colors.blue),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
