import 'dart:ui' show Rect, Size;

import 'preview_fit.dart';

/// Computes the rect, within a widget of [widgetSize], that the preview's
/// actual content occupies once [contentSize] (the Texture's native
/// aspect ratio) is laid out under [fit].
///
/// Pure function, no Flutter widget dependency beyond `Rect`/`Size` --
/// deliberately kept this way so it stays exhaustively unit-testable and
/// is safe to reuse, unchanged, for annotation coordinate mapping once
/// that lands: the overlay and the preview must agree on exactly where
/// the image content is, and sharing this one function is what
/// guarantees that rather than hoping two separate implementations never
/// drift apart.
///
/// - [PreviewFit.cover]: the returned rect is scaled up to fully cover
///   [widgetSize], centered, extending beyond the widget's bounds on one
///   axis (the caller clips to the widget's bounds when painting).
/// - [PreviewFit.contain]: the returned rect fits entirely within
///   [widgetSize], centered, with letterboxing (empty space) on one axis.
Rect computePreviewContentRect({
  required Size widgetSize,
  required Size contentSize,
  required PreviewFit fit,
}) {
  if (widgetSize.isEmpty || contentSize.isEmpty) {
    return Rect.fromLTWH(0, 0, widgetSize.width, widgetSize.height);
  }

  final widgetAspect = widgetSize.width / widgetSize.height;
  final contentAspect = contentSize.width / contentSize.height;

  final contentIsRelativelyWider = contentAspect > widgetAspect;

  // cover: when content is relatively wider than the widget, scale to
  // match the widget's height (so width overflows); contain does the
  // opposite -- scale to match the widget's width (so height fits).
  final matchHeight = fit == PreviewFit.cover
      ? contentIsRelativelyWider
      : !contentIsRelativelyWider;

  late double scaledWidth;
  late double scaledHeight;
  if (matchHeight) {
    scaledHeight = widgetSize.height;
    scaledWidth = scaledHeight * contentAspect;
  } else {
    scaledWidth = widgetSize.width;
    scaledHeight = scaledWidth / contentAspect;
  }

  final left = (widgetSize.width - scaledWidth) / 2;
  final top = (widgetSize.height - scaledHeight) / 2;

  return Rect.fromLTWH(left, top, scaledWidth, scaledHeight);
}

/// How many clockwise quarter-turns a `RotatedBox` needs to correct a
/// camera Texture's rotation, given the sensor's physical mounting angle
/// and the current device orientation.
///
/// Required because Flutter's `Texture`/`SurfaceProducer` rendering path
/// does not apply the sensor's rotation metadata itself on API 29+
/// devices (`TextureRegistry.SurfaceProducer.handlesCropAndRotation()`
/// reports `false` on that path) -- confirmed on a physical device, where
/// omitting this correction left the preview rotated 90 degrees from
/// upright. Mirrors the formula Flutter's own official
/// `camera_android_camerax` plugin uses after hitting the identical bug
/// (flutter/packages#8629): `(sensorOrientationDegrees -
/// deviceOrientationDegrees * sign + 360) % 360`, floor-divided into
/// quarter turns.
///
/// [sign] is `-1` for the back camera and `1` for the front camera -- the
/// front sensor is mounted mirrored relative to the back, which flips
/// the sign of the correction needed.
int computeRotationQuarterTurns({
  required int sensorOrientationDegrees,
  required int deviceOrientationDegrees,
  required int sign,
}) {
  final rotationDegrees =
      (sensorOrientationDegrees - deviceOrientationDegrees * sign + 360) % 360;
  return rotationDegrees ~/ 90;
}
