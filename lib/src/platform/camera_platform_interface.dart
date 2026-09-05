import '../camera/camera_capability.dart';

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

/// Abstract contract between `CustomCameraController` and whatever
/// implementation actually talks to the platform. The generated Pigeon
/// client is the default (Android) implementation; a fake implementation
/// is used in controller unit tests to exercise the state machine without
/// real hardware; a future iOS implementation attaches here too.
abstract class CameraPlatform {
  /// Binds a camera session for [initialLensDirection] and returns the
  /// detected device capability. Throws a `CustomCameraException` subtype
  /// on failure — never a raw platform exception.
  Future<CameraCapability> initialize(CameraLensDirection initialLensDirection);

  /// Unbinds the camera session. Safe to call from any state, including
  /// when no session is bound — a no-op, not an error.
  Future<void> dispose();

  /// Fires when the native side observes a state change Dart did not
  /// initiate — e.g. the OS reclaiming the camera. Implementations that
  /// cannot detect such events (a fake used in tests) may simply never
  /// call the listeners they're given.
  void setEventListener(
    void Function(CameraPlatformEvent event, CameraPlatformError? error)?
    listener,
  );
}
