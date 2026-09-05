/// Typed exception hierarchy for d3_camera. No call site should ever throw
/// a generic `Exception('camera error')` — every failure mode maps onto a
/// specific subtype here so consumers can branch on what actually went
/// wrong instead of parsing a message string.
sealed class CustomCameraException implements Exception {
  const CustomCameraException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The camera permission was denied (or not yet granted) when
/// `initialize()` was called. The package does not request permissions
/// itself — see `CustomCameraController.initialize` for why.
final class CameraPermissionDeniedException extends CustomCameraException {
  const CameraPermissionDeniedException([
    super.message = 'Camera permission was denied.',
  ]);
}

/// The requested camera (or any camera) is unavailable — in use by
/// another app, physically absent, or reclaimed by the OS.
final class CameraUnavailableException extends CustomCameraException {
  const CameraUnavailableException(super.message);
}

/// `initialize()` failed for a reason other than permissions or
/// availability (e.g. the native session failed to bind).
final class CameraInitializationException extends CustomCameraException {
  const CameraInitializationException(super.message);
}

/// A controller method was called while the controller was in a state
/// that does not permit it — e.g. capturing during `initializing`. See
/// the controller state machine's race-condition table for the full list
/// of guarded transitions.
///
/// [currentStatusName] is the `CameraStatus` enum value's `.name` rather
/// than the enum itself, so this file has no dependency on `camera/` —
/// errors/ is a leaf the rest of the package can depend on, not the
/// reverse.
final class InvalidCameraStateException extends CustomCameraException {
  InvalidCameraStateException({
    required this.currentStatusName,
    required this.attemptedOperation,
  }) : super(
         'Cannot $attemptedOperation while camera status is '
         '"$currentStatusName".',
       );

  final String currentStatusName;
  final String attemptedOperation;
}

/// The requested capability (e.g. manual focus) is not supported by the
/// active device, per `CameraCapability`.
final class UnsupportedCapabilityException extends CustomCameraException {
  const UnsupportedCapabilityException(String capability)
    : super('Capability not supported on this device: $capability');
}

/// `captureImage()` failed at the native layer.
final class CaptureFailedException extends CustomCameraException {
  const CaptureFailedException(super.message);
}

/// Decode/crop/composite failed during image export.
final class ImageProcessingException extends CustomCameraException {
  const ImageProcessingException(super.message);
}

/// Encoding or writing the exported file failed.
final class ExportFailedException extends CustomCameraException {
  const ExportFailedException(super.message);
}

/// The OS reclaimed the camera out from under an active session (e.g.
/// another app took priority, or a permission was revoked mid-session).
final class CameraDisconnectedException extends CustomCameraException {
  const CameraDisconnectedException(super.message);
}
