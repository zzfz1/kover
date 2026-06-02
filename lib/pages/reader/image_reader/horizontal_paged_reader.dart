import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/pages/reader/image_reader/paged_image_gesture_controller.dart';
import 'package:kover/pages/reader/image_reader/seamless_paged_view.dart';
import 'package:kover/pages/reader/image_reader/zoomable_paged_image.dart';
import 'package:kover/riverpod/providers/book.dart';
import 'package:kover/riverpod/providers/reader//reader.dart';
import 'package:kover/riverpod/providers/reader/reader_navigation.dart';
import 'package:kover/riverpod/providers/settings/image_reader_settings.dart';
import 'package:kover/widgets/util/async_value.dart';

class HorizontalPagedReader extends HookConsumerWidget {
  final int seriesId;
  final int chapterId;

  const HorizontalPagedReader({
    super.key,
    required this.seriesId,
    required this.chapterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = readerProvider(seriesId: seriesId, chapterId: chapterId);

    final settings = ref.watch(imageReaderSettingsProvider(seriesId: seriesId));
    final reader = ref.watch(provider);

    final navProvider = readerNavigationProvider(
      seriesId: seriesId,
      chapterId: chapterId,
    );

    final navState = ref.watch(navProvider);

    return Async3(
      asyncValue1: reader,
      asyncValue2: settings,
      asyncValue3: navState,
      data: (reader, settings, navState) {
        return HookConsumer(
          builder: (context, ref, _) {
            final pageController = usePageController(
              initialPage: navState.currentPage,
            );
            final gestureController = useMemoized(
              () => PagedImageGestureController(
                initialPage: navState.currentPage,
              ),
            );

            useEffect(() => gestureController.dispose, [gestureController]);

            ref.listen(
              navProvider.select((s) => s.whenData((s) => s.currentPage)),
              (previous, next) {
                next.whenData((next) {
                  if (pageController.hasClients &&
                      pageController.page?.round() != next) {
                    gestureController.resetForPage(next);

                    final isSequential =
                        previous != null &&
                        previous.value != null &&
                        (next - previous.value!).abs() == 1;

                    isSequential
                        ? pageController.animateToPage(
                            next,
                            duration: 200.ms,
                            curve: Curves.easeInOut,
                          )
                        : pageController.jumpToPage(next);
                  }
                });
              },
            );

            final fit = switch (settings.scaleType) {
              .contain => BoxFit.contain,
              .fitWidth => BoxFit.fitWidth,
              .fitHeight => BoxFit.fitHeight,
            };

            final content = SeamlessPagedView(
              pageController: pageController,
              gestureController: gestureController,
              itemCount: reader.totalPages,
              reverse: settings.readDirection == .rightToLeft,
              fit: fit,
              child: PageView.builder(
                controller: pageController,
                allowImplicitScrolling: true,
                scrollDirection: .horizontal,
                reverse: settings.readDirection == .rightToLeft,
                itemCount: reader.totalPages,
                pageSnapping: true,
                // SeamlessPagedView owns drags so image overflow can hand off
                // to pagination without starting a second gesture.
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  ref.read(navProvider.notifier).jumpToPage(index);
                },
                itemBuilder: (context, index) {
                  return Async(
                    asyncValue: ref.watch(
                      imagePageProvider(chapterId: chapterId, page: index),
                    ),
                    data: (data) {
                      return ZoomablePagedImage(
                        page: index,
                        data: data.data,
                        fit: fit,
                        controller: gestureController,
                      );
                    },
                  );
                },
              ),
            );

            if (settings.ignoreSafeAreas) {
              return content;
            }

            return SafeArea(child: content);
          },
        );
      },
    );
  }
}
