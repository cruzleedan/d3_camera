// Pigeon source-of-truth schema for the Dart <-> Kotlin camera boundary.
//
// Regenerate after any change with:
//   dart run pigeon --input pigeon/camera_api.dart
//
// Phase 2 scope: adds preview (bound as part of initialize(), since
// CameraX binds all use cases together in one bindToLifecycle() call --
// there is no meaningful "initialized but no preview" state), still
// capture, and flash/zoom/focus/exposure/switch controls. See
// context/work/0021 (workspace root) for the phase's own scope notes.
//
// Pigeon generates type-safe code on both sides of a MethodChannel from
// this one schema -- a renamed/added field is a compile error in Dart and
// Kotlin instead of a runtime string-key mismatch. Live preview FRAMES do
// NOT go through this contract; only the texture id does. Frames are
// delivered via a Flutter Texture, which is the only mechanism that gets
// camera frames onto Flutter's GPU-composited surface without a
// per-frame channel round trip.

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

/// Preview/capture aspect ratio, matching the presets native camera apps
/// expose (Pixel Camera, iOS Camera both default to 4:3 with a 16:9
/// toggle). Applied identically to Preview and ImageCapture via a shared
/// CameraX ResolutionSelector/AspectRatioStrategy, so what's framed live
/// always matches what's captured -- see CameraXSession's own docs on
/// why both use cases must share one strategy.
enum AspectRatioPresetData { ratio4x3, ratio16x9 }

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

/// Result of any [CameraHostApi] call that (re)binds the CameraX session:
/// [CameraHostApi.initialize], [CameraHostApi.switchCamera], and
/// [CameraHostApi.setAspectRatio] all rebind the whole use-case group in
/// one bindToLifecycle() call and so all three can affect every field
/// here -- texture id, preview resolution, sensor orientation, and
/// capability are re-read fresh after every rebind, never assumed to
/// carry over from a previous binding.
class CameraSessionResultData {
  const CameraSessionResultData({
    required this.capability,
    required this.textureId,
    required this.previewWidth,
    required this.previewHeight,
    required this.sensorOrientationDegrees,
  });

  final CameraCapabilityData capability;
  final int textureId;

  /// The bound Preview use case's actual output resolution, in sensor
  /// (unrotated-for-display) pixels -- CustomCameraPreview needs this to
  /// compute cover/contain layout against the Texture's real aspect
  /// ratio rather than assuming one.
  final int previewWidth;
  final int previewHeight;

  /// CameraCharacteristics.SENSOR_ORIENTATION for the bound lens, in
  /// degrees. Flutter's Texture/SurfaceProducer path does NOT
  /// automatically correct for this on API 29+ (the ImageReader-backed
  /// rendering path, used on nearly all current devices, explicitly does
  /// not handle rotation metadata -- see
  /// TextureRegistry.SurfaceProducer#handlesCropAndRotation). Rotation
  /// correction is applied in Dart, in CustomCameraPreview, using this
  /// value -- mirroring the same fix Flutter's own official
  /// camera_android_camerax plugin applies (flutter/packages#8629)
  /// after hitting the identical bug.
  final int sensorOrientationDegrees;
}

/// Flash behavior for still capture. Auto and on are only meaningful on
/// lenses with a flash unit -- see [CameraCapabilityData.hasFlash].
enum FlashModeData { off, on, auto }

/// A point in normalized [0,1] preview-space, used for tap-to-focus and
/// tap-to-expose. Normalized rather than pixel-based so the Dart side
/// never needs to know the native preview surface's actual resolution --
/// consistent with the package's normalized-coordinate approach used
/// throughout (see the design doc's coordinate system architecture).
class NormalizedPointData {
  const NormalizedPointData({required this.x, required this.y});

  final double x;
  final double y;
}

/// What a still-capture call produced.
class CaptureResultData {
  const CaptureResultData({
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
  final LensDirection capturedLensDirection;
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
  /// Binds a CameraX session -- Preview and ImageCapture use cases -- to
  /// the plugin's own lifecycle owner (not an Activity's) and returns the
  /// detected device capability plus the texture id the preview is
  /// publishing to. Throws (via a FlutterError on the generated Dart
  /// side) if the requested lens direction is unavailable or the camera
  /// permission is not granted.
  @async
  CameraSessionResultData initialize(
    LensDirection initialLensDirection,
    AspectRatioPresetData initialAspectRatio,
  );

  /// Unbinds the CameraX session and releases the camera. Safe to call
  /// from any state; calling it twice is a no-op, not an error.
  @async
  void dispose();

  /// Captures a still image at full resolution and writes it to a
  /// package-owned cache file. Throws if called while no session is
  /// bound.
  @async
  CaptureResultData captureImage();

  /// Sets flash behavior for subsequent captures. Throws a FlutterError
  /// if the active lens has no flash unit -- callers should check
  /// [CameraCapabilityData.hasFlash] first, this is a defensive backstop.
  @async
  void setFlashMode(FlashModeData mode);

  /// Unbinds the current session and rebinds for the opposite lens
  /// direction, returning the newly bound capability and texture id (both
  /// may differ from the previous lens).
  @async
  CameraSessionResultData switchCamera(LensDirection lensDirection);

  /// Unbinds the current session and rebinds with a new
  /// AspectRatioStrategy for both Preview and ImageCapture, returning the
  /// newly bound session's texture id and preview resolution (both
  /// change on this rebind, since a different aspect ratio means a
  /// different negotiated stream size).
  @async
  CameraSessionResultData setAspectRatio(AspectRatioPresetData aspectRatio);

  /// Sets the zoom ratio. The native side clamps to the device's actual
  /// range as a defensive backstop -- see
  /// CameraCapability.clampZoom, which the Dart controller already
  /// applies before this is ever called.
  @async
  void setZoom(double zoomRatio);

  /// Triggers autofocus AND auto-exposure metering together at a
  /// normalized preview point (the standard "tap to focus" gesture), or
  /// resumes continuous autofocus/default metering if [point] is null.
  ///
  /// Deliberately one call, not two -- CameraX's startFocusAndMetering()
  /// cancels an in-flight call when a second one starts on the same
  /// camera, so issuing separate AF and AE calls for the same tap is a
  /// guaranteed race, not just a theoretical one.
  @async
  void setMeteringPoint(NormalizedPointData? point);

  /// Sets exposure compensation, in EV. The native side clamps to the
  /// device's actual range as a defensive backstop, mirroring [setZoom].
  @async
  void setExposureCompensation(double ev);
}

/// Kotlin -> Dart. Async, natively-initiated notifications the controller
/// cannot poll for -- e.g. the camera permission being revoked at the OS
/// level while a session is active.
@FlutterApi()
abstract class CameraFlutterApi {
  void onCameraEvent(NativeCameraEvent event, CameraErrorData? error);
}
