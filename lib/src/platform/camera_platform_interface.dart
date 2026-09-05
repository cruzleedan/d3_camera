import 'dart:ui' show Size;

import '../camera/camera_capability.dart';
import '../camera/capture_result.dart';
import '../camera/flash_mode.dart';
import '../coordinates/normalized_point.dart';

/// Events the platform side can push to Dart without being asked — see
/// `CameraFlutterApi` in the Pigeon schema. Kept as a small Dart-side enum
/// (rather than exposing the generated `NativeCameraEvent` directly)
/// so callers of [CameraPlatform] never need to import anything from
/// `platform/pigeon/`.
enum CameraPlatformEvent { disconnected, permissionRevoked, error }

/// A natively-reported error accompanying a [CameraPlatformEvent.error]
/// notification.
class CameraPlatformError {
  const CameraPlatformError({required this.code, required this.message});

  final String code;
  final String message;
}

/// What a successful [CameraPlatform.initialize] or
/// [CameraPlatform.switchCamera] call returns: the newly bound session's
/// capability, the Flutter texture id its preview is publishing to, and
/// the preview's native resolution (for `CustomCameraPreview`'s
/// cover/contain layout math). Both calls return the same shape because
/// switching cameras rebinds the whole CameraX use-case group, including
/// Preview — all of these may change and must be re-read for the newly
/// bound lens.
class CameraSessionInfo {
  const CameraSessionInfo({
    required this.capability,
    required this.textureId,
    required this.previewSize,
  });

  final CameraCapability capability;
  final int textureId;
  final Size previewSize;
}

/// Abstract contract between `CustomCameraController` and whatever
/// implementation actually talks to the platform. The generated Pigeon
/// client is the default (Android) implementation; a fake implementation
/// is used in controller unit tests to exercise the state machine without
/// real hardware; a future iOS implementation attaches here too.
abstract class CameraPlatform {
  /// Binds a camera session (Preview + ImageCapture use cases) for
  /// [initialLensDirection] and returns the detected device capability
  /// plus the bound preview's texture id. Throws a `CustomCameraException`
  /// subtype on failure — never a raw platform exception.
  Future<CameraSessionInfo> initialize(CameraLensDirection initialLensDirection);

  /// Unbinds the camera session. Safe to call from any state, including
  /// when no session is bound — a no-op, not an error.
  Future<void> dispose();

  /// Captures a still image at full resolution.
  Future<ImageCaptureResult> captureImage();

  /// Sets flash behavior for subsequent captures.
  Future<void> setFlashMode(FlashMode mode);

  /// Unbinds the current session and rebinds for [lensDirection],
  /// returning the newly bound capability and texture id.
  Future<CameraSessionInfo> switchCamera(CameraLensDirection lensDirection);

  /// Sets the zoom ratio. Callers are expected to have already clamped
  /// via `CameraCapability.clampZoom` — this exists as the platform call,
  /// not a second clamping authority.
  Future<void> setZoom(double zoomRatio);

  /// Triggers autofocus AND auto-exposure metering together at [point]
  /// (the standard tap-to-focus gesture), or resumes continuous
  /// autofocus/default metering if `null`. One call, not two — see the
  /// Pigeon schema's own note on why separate AF/AE calls for the same
  /// tap is a guaranteed cancellation race on CameraX.
  Future<void> setMeteringPoint(NormalizedPoint? point);

  /// Sets exposure compensation, in EV. Callers are expected to have
  /// already clamped via `CameraCapability.clampExposureCompensation`.
  Future<void> setExposureCompensation(double ev);

  /// Fires when the native side observes a state change Dart did not
  /// initiate — e.g. the OS reclaiming the camera. Implementations that
  /// cannot detect such events (a fake used in tests) may simply never
  /// call the listeners they're given.
  void setEventListener(
    void Function(CameraPlatformEvent event, CameraPlatformError? error)?
    listener,
  );
}
