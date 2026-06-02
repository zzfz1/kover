import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kover/pages/reader/image_reader/paged_image_gesture_controller.dart';

class ZoomablePagedImage extends StatefulWidget {
  final int page;
  final Uint8List data;
  final BoxFit fit;
  final PagedImageGestureController controller;

  const ZoomablePagedImage({
    super.key,
    required this.page,
    required this.data,
    required this.fit,
    required this.controller,
  });

  @override
  State<ZoomablePagedImage> createState() => _ZoomablePagedImageState();
}

class _ZoomablePagedImageState extends State<ZoomablePagedImage> {
  late Image _image;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  Size? _intrinsicSize;

  @override
  void initState() {
    super.initState();
    _image = _createImage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(ZoomablePagedImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.data != oldWidget.data) {
      _image = _createImage();
      _intrinsicSize = null;
      _resolveImage();
    } else if (widget.controller != oldWidget.controller ||
        widget.page != oldWidget.page) {
      final intrinsicSize = _intrinsicSize;
      if (intrinsicSize != null) {
        widget.controller.setIntrinsicImageSize(widget.page, intrinsicSize);
      }
    }
  }

  @override
  void dispose() {
    final listener = _imageStreamListener;
    if (listener != null) {
      _imageStream?.removeListener(listener);
    }

    super.dispose();
  }

  Image _createImage() {
    return Image.memory(widget.data, fit: BoxFit.fill, gaplessPlayback: true);
  }

  void _resolveImage() {
    final stream = _image.image.resolve(createLocalImageConfiguration(context));
    if (_imageStream?.key == stream.key) return;

    final oldListener = _imageStreamListener;
    if (oldListener != null) {
      _imageStream?.removeListener(oldListener);
    }

    _imageStream = stream;
    _imageStreamListener = ImageStreamListener((info, synchronousCall) {
      final intrinsicSize = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (_intrinsicSize == intrinsicSize) return;

      _intrinsicSize = intrinsicSize;
      widget.controller.setIntrinsicImageSize(widget.page, intrinsicSize);

      if (!synchronousCall && mounted) {
        setState(() {});
      }
    });
    stream.addListener(_imageStreamListener!);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final intrinsicSize = _intrinsicSize;
          if (intrinsicSize == null) {
            return _image;
          }

          final imageSize =
              PagedImageGestureController.calculateFittedImageSize(
                intrinsicSize: intrinsicSize,
                viewportSize: constraints.biggest,
                fit: widget.fit,
              );

          return OverflowBox(
            alignment: Alignment.center,
            minWidth: imageSize.width,
            maxWidth: imageSize.width,
            minHeight: imageSize.height,
            maxHeight: imageSize.height,
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, child) {
                final isActivePage =
                    widget.controller.activePage == widget.page;

                return Transform.translate(
                  offset: isActivePage
                      ? widget.controller.translation
                      : Offset.zero,
                  child: Transform.scale(
                    scale: isActivePage ? widget.controller.scale : 1.0,
                    child: child,
                  ),
                );
              },
              child: SizedBox.fromSize(size: imageSize, child: _image),
            ),
          );
        },
      ),
    );
  }
}
