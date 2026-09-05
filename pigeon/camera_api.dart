// Pigeon source-of-truth schema for the Dart <-> Kotlin camera boundary.
//
// Regenerate after any change with:
//   dart run pigeon --input pigeon/camera_api.dart
//
// Phase 1 scope only: initialize/dispose and a one-time capability query,
// plus an async event callback for state/error notifications. No capture,
// preview, or control methods (zoom/flash/focus/exposure) yet -- those
// are added to this same file in a later pass, not scaffolded
// speculatively now.
//
// Pigeon generates type-safe code on both sides of a MethodChannel from
// this one schema -- a renamed/added field is a compile error in Dart and
// Kotlin instead of a runtime string-key mismatch. Live preview frames do
// NOT go through this contract; they're delivered via a Flutter Texture,
// which is the only mechanism that gets camera frames onto Flutter's
// GPU-composited surface without a per-frame channel round trip.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/pigeon/camera_api.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/d3/d3_camera/CameraApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.d3.d3_camera'),
    dartPackageName: 'd3_camera',
  ),
)

/// Which physical camera a session is bound to.
enum LensDirection { front, back }

/// Device-reported limits, read once at initialization time. The
/// governing rule: detect, never assume -- every field here is queried
/// from CameraCharacteristics/CameraInfo, never a hardcoded default,
/// since flash/zoom/focus/exposure support varies widely across Android
/// hardware.
class CameraCapabilityData {
  const CameraCapabilityData({
    required this.hasFlash,
    required this.minZoomRatio,
    required this.maxZoomRatio,
    required this.supportsTapToFocus,
    required this.supportsExposureCompensation,
    required this.minExposureCompensation,
    required this.maxExposureCompensation,
    required this.availableLenses,
  });

  final bool hasFlash;
  final double minZoomRatio;
  final double maxZoomRatio;
  final bool supportsTapToFocus;
  final bool supportsExposureCompensation;
  final double minExposureCompensation;
  final double maxExposureCompensation;
  final List<LensDirection> availableLenses;
}

/// The subset of camera state changes the native side can independently
/// observe and must report asynchronously -- e.g. the OS reclaiming the
/// camera, or a permission revoked mid-session. The full controller state
/// machine, including states reachable only from Dart-initiated calls,
/// lives in CustomCameraController itself, not here.
enum NativeCameraEvent { disconnected, permissionRevoked, error }

class CameraErrorData {
  const CameraErrorData({required this.code, required this.message});

  /// A stable code Dart maps onto its own typed exception hierarchy --
  /// not a free-text message on its own, so callers can branch on the
  /// failure kind rather than pattern-matching on message strings.
  final String code;
  final String message;
}

/// Dart -> Kotlin. Commands the Dart controller issues to the native
/// camera session.
@HostApi()
abstract class CameraHostApi {
  /// Binds a CameraX session to the plugin's own lifecycle owner (not an
  /// Activity's) and returns the detected device capability. Throws (via
  /// a FlutterError on the generated Dart side) if the requested lens
  /// direction is unavailable or the camera permission is not granted.
  @async
  CameraCapabilityData initialize(LensDirection initialLensDirection);

  /// Unbinds the CameraX session and releases the camera. Safe to call
  /// from any state; calling it twice is a no-op, not an error.
  @async
  void dispose();
}

/// Kotlin -> Dart. Async, natively-initiated notifications the controller
/// cannot poll for -- e.g. the camera permission being revoked at the OS
/// level while a session is active.
@FlutterApi()
abstract class CameraFlutterApi {
  void onCameraEvent(NativeCameraEvent event, CameraErrorData? error);
}
