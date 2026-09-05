import 'package:meta/meta.dart';

import 'camera_capability.dart';

/// What `CustomCameraController.captureImage()` returns. Immutable.
///
/// [filePath] points to a package-owned cache file -- the caller owns its
/// lifecycle from this point on (move, persist, or delete it); the
/// package never assumes ownership of a file after handing back its
/// path, and never silently deletes or retains one either.
@immutable
class ImageCaptureResult {
  const ImageCaptureResult({
    required this.filePath,
    required this.width,
    required this.height,
    required this.exifOrientationDegrees,
    required this.capturedLensDirection,
  });

  final String filePath;
  final int width;
  final int height;
  final int exifOrientationDegrees;
  final CameraLensDirection capturedLensDirection;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageCaptureResult &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath &&
          width == other.width &&
          height == other.height &&
          exifOrientationDegrees == other.exifOrientationDegrees &&
          capturedLensDirection == other.capturedLensDirection;

  @override
  int get hashCode => Object.hash(
    filePath,
    width,
    height,
    exifOrientationDegrees,
    capturedLensDirection,
  );

  @override
  String toString() =>
      'ImageCaptureResult(filePath: $filePath, width: $width, '
      'height: $height, exifOrientationDegrees: $exifOrientationDegrees, '
      'capturedLensDirection: $capturedLensDirection)';
}
