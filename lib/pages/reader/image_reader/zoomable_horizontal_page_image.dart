import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kover/pages/reader/image_reader/paged_image_gesture_controller.dart';

class ZoomableHorizontalPageImage extends HookWidget {
  final int page;
  final Uint8List data;
  final BoxFit fit;
  final PagedImageGestureController controller;

  const ZoomableHorizontalPageImage(
    this.data, {
    super.key,
    required this.page,
    required this.fit,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final imageState = useMemoized(
      () => _ImageState(
        Image.memory(data, fit: BoxFit.fill, gaplessPlayback: true),
      ),
      [data],
    );
    final renderVersion = useState(0);
    final imageConfiguration = createLocalImageConfiguration(context);

    // Image listeners may fire synchronously while building. Only trigger a
    // rebuild when resolution completes asynchronously.
    useEffect(() {
      final stream = imageState.image.image.resolve(imageConfiguration);
      final listener = ImageStreamListener((info, synchronousCall) {
        final intrinsicSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        final hasChanged = imageState.intrinsicSize != intrinsicSize;

        imageState.intrinsicSize = intrinsicSize;
        controller.setIntrinsicImageSize(page, intrinsicSize);

        if (hasChanged && !synchronousCall) {
          renderVersion.value++;
        }
      });

      stream.addListener(listener);
      return () => stream.removeListener(listener);
    }, [controller, imageConfiguration, imageState, page]);

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final intrinsicSize = imageState.intrinsicSize;
          if (intrinsicSize == null) {
            return imageState.image;
          }

          final imageSize =
              PagedImageGestureController.calculateFittedImageSize(
                intrinsicSize: intrinsicSize,
                viewportSize: constraints.biggest,
                fit: fit,
              );

          return OverflowBox(
            alignment: Alignment.center,
            minWidth: imageSize.width,
            maxWidth: imageSize.width,
            minHeight: imageSize.height,
            maxHeight: imageSize.height,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final isActivePage = controller.activePage == page;

                return Transform.translate(
                  offset: isActivePage ? controller.translation : Offset.zero,
                  child: Transform.scale(
                    scale: isActivePage ? controller.scale : 1.0,
                    child: child,
                  ),
                );
              },
              child: SizedBox.fromSize(
                size: imageSize,
                child: imageState.image,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImageState {
  final Image image;
  Size? intrinsicSize;

  _ImageState(this.image);
}
