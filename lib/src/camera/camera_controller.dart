import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;

import '../coordinates/normalized_point.dart';
import '../errors/camera_exceptions.dart';
import '../platform/camera_platform_interface.dart';
import '../platform/method_channel_camera.dart';
import 'camera_capability.dart';
import 'camera_configuration.dart';
import 'camera_state.dart';
import 'capture_result.dart';
import 'flash_mode.dart';

/// Owns the camera lifecycle and hardware state. The single object
/// consumers hold and pass to `CustomCameraPreview` and their own
/// controls.
///
/// Lifecycle: construct → [initialize] → used → [dispose]. Disposal is
/// mandatory and irreversible, matching Flutter's own controller
/// conventions (`TextEditingController`, `AnimationController`).
///
/// Every mutating method checks [value].status first. Calls made during a
/// transient state (`initializing`, `capturing`, `switchingCamera`,
/// `disposing`) throw [InvalidCameraStateException] immediately rather
/// than queuing — queuing would hide bugs in consumer code that a loud
/// failure surfaces during development.
class CustomCameraController extends ChangeNotifier
    implements ValueListenable<CameraState> {
  CustomCameraController({
    required this.configuration,
    @visibleForTesting CameraPlatform? platform,
  }) : _platform = platform ?? MethodChannelCameraPlatform() {
    _platform.setEventListener(_handlePlatformEvent);
  }

  final CameraConfiguration configuration;
  final CameraPlatform _platform;

  CameraState _value = const CameraState.initial();
  bool _hasDisposed = false;

  @override
  CameraState get value => _value;

  /// Device-detected limits. Throws [StateError] before the first
  /// successful [initialize] — read [value] first if the caller isn't
  /// sure initialization has completed.
  CameraCapability get capability {
    final capability = _value.capability;
    if (capability == null) {
      throw StateError(
        'CameraCapability is not available before initialize() completes.',
      );
    }
    return capability;
  }

  void _setValue(CameraState newValue) {
    _value = newValue;
    notifyListeners();
  }

  void _requireStatus(CameraStatus expected, String operation) {
    if (_value.status != expected) {
      throw InvalidCameraStateException(
        currentStatusName: _value.status.name,
        attemptedOperation: operation,
      );
    }
  }

  /// Binds a camera session for [CameraConfiguration.initialLensDirection]
  /// and transitions to [CameraStatus.ready] on success, or
  /// [CameraStatus.error] on failure.
  ///
  /// The package does not request the camera permission itself — that's
  /// deliberately left to the consuming app (which may already standardize
  /// on a permissions plugin this package shouldn't force a dependency
  /// on). If the permission isn't already granted, this throws
  /// [CameraPermissionDeniedException] rather than triggering an OS
  /// prompt.
  ///
  /// Throws [InvalidCameraStateException] if called while already
  /// [CameraStatus.initializing], [CameraStatus.ready], or
  /// [CameraStatus.disposing]/[CameraStatus.disposed] — call [dispose]
  /// first to re-initialize with a different configuration.
  Future<void> initialize() async {
    _requireStatus(CameraStatus.uninitialized, 'initialize');

    _setValue(_value.copyWith(status: CameraStatus.initializing));

    // Locks the UI to portrait for the lifetime of the camera session,
    // matching every native camera app (Pixel Camera, iOS Camera): the
    // screen itself never reflows to landscape when the device rotates,
    // only individual control icons do (a further refinement not yet
    // implemented here). This is a controller-lifecycle concern, not
    // something left to the consuming app to remember on every screen
    // that hosts a camera — a real consuming app may support landscape
    // elsewhere in its own UI, and this lock is scoped to exactly the
    // lifetime of this controller's session, restored in full on
    // dispose(). It also happens to make the rotation-correction math
    // in `CustomCameraPreview` sound: that correction currently assumes
    // a fixed portraitUp device orientation, which this lock guarantees
    // is actually true rather than merely assumed.
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    try {
      final info = await _platform.initialize(
        configuration.initialLensDirection,
      );
      _setValue(
        _value.copyWith(
          status: CameraStatus.ready,
          activeLens: configuration.initialLensDirection,
          capability: info.capability,
          textureId: info.textureId,
          previewSize: info.previewSize,
          sensorOrientationDegrees: info.sensorOrientationDegrees,
        ),
      );
    } on CustomCameraException catch (e) {
      _setValue(_value.copyWith(status: CameraStatus.error, lastError: e));
      rethrow;
    }
  }

  /// Captures a still image at full resolution. Only valid while
  /// [CameraStatus.ready]; transitions through [CameraStatus.capturing]
  /// and back to [CameraStatus.ready] on success, or to
  /// [CameraStatus.error] on failure.
  ///
  /// Two rapid calls are not queued — the second throws
  /// [InvalidCameraStateException] while the first is still in flight, by
  /// design: burst capture, if ever needed, is a distinct future API, not
  /// an implicit queue on this one.
  Future<ImageCaptureResult> captureImage() async {
    _requireStatus(CameraStatus.ready, 'captureImage');

    _setValue(_value.copyWith(status: CameraStatus.capturing));

    try {
      final result = await _platform.captureImage();
      _setValue(_value.copyWith(status: CameraStatus.ready));
      return result;
    } on CustomCameraException catch (e) {
      _setValue(_value.copyWith(status: CameraStatus.error, lastError: e));
      rethrow;
    }
  }

  /// Sets flash behavior for subsequent captures. Only valid while
  /// [CameraStatus.ready]. Does not check
  /// [CameraCapability.hasFlash] itself — the platform layer is the
  /// authority and throws a typed exception if the active lens has no
  /// flash unit; consumers should still check `hasFlash` to decide
  /// whether to show the control at all, per the design's
  /// detect-never-assume rule.
  Future<void> setFlashMode(FlashMode mode) async {
    _requireStatus(CameraStatus.ready, 'setFlashMode');

    try {
      await _platform.setFlashMode(mode);
      _setValue(_value.copyWith(flashMode: mode));
    } on CustomCameraException catch (e) {
      _setValue(_value.copyWith(status: CameraStatus.error, lastError: e));
      rethrow;
    }
  }

  /// Unbinds the current session and rebinds for [to] (or the opposite of
  /// the currently active lens if [to] is omitted). Only valid while
  /// [CameraStatus.ready]; transitions through
  /// [CameraStatus.switchingCamera]. On success, [CameraState.capability]
  /// and [CameraState.textureId] are replaced with the newly bound
  /// session's values — they are not assumed to carry over, since a
  /// different physical lens can have entirely different capability.
  Future<void> switchCamera({CameraLensDirection? to}) async {
    _requireStatus(CameraStatus.ready, 'switchCamera');

    final targetLens = to ?? _oppositeLens(_value.activeLens!);

    _setValue(
      _value.copyWith(status: CameraStatus.switchingCamera, clearTextureId: true),
    );

    try {
      final info = await _platform.switchCamera(targetLens);
      _setValue(
        _value.copyWith(
          status: CameraStatus.ready,
          activeLens: targetLens,
          capability: info.capability,
          textureId: info.textureId,
          previewSize: info.previewSize,
          sensorOrientationDegrees: info.sensorOrientationDegrees,
        ),
      );
    } on CustomCameraException catch (e) {
      _setValue(_value.copyWith(status: CameraStatus.error, lastError: e));
      rethrow;
    }
  }

  /// Sets the zoom ratio, clamped to [CameraCapability]'s reported range
  /// — a zoom slider dragged past a device's maximum simply stops there
  /// rather than throwing. Only valid while [CameraStatus.ready].
  Future<void> setZoom(double zoomRatio) async {
    _requireStatus(CameraStatus.ready, 'setZoom');

    final clamped = capability.clampZoom(zoomRatio);
    try {
      await _platform.setZoom(clamped);
      _setValue(_value.copyWith(zoomRatio: clamped));
    } on CustomCameraException catch (e) {
      _setValue(_value.copyWith(status: CameraStatus.error, lastError: e));
      rethrow;
    }
  }

  /// Triggers autofocus AND auto-exposure metering together at
  /// [normalizedPoint] — the standard tap-to-focus gesture — or resumes
  /// continuous autofocus/default metering if `null`. Only valid while
  /// [CameraStatus.ready].
  ///
  /// Deliberately one method, not two separate focus/exposure calls:
  /// CameraX's underlying `startFocusAndMetering` cancels an in-flight
  /// call when a second one starts on the same camera, so issuing
  /// separate AF and AE calls for the same tap is a guaranteed
  /// cancellation race, not just a theoretical one — confirmed on-device
  /// during Phase 2 development.
  Future<void> setMeteringPoint(NormalizedPoint? normalizedPoint) async {
    _requireStatus(CameraStatus.ready, 'setMeteringPoint');

    try {
      await _platform.setMeteringPoint(normalizedPoint);
    } on CustomCameraException catch (e) {
      _setValue(_value.copyWith(status: CameraStatus.error, lastError: e));
      rethrow;
    }
  }

  /// Sets exposure compensation, in EV, clamped to [CameraCapability]'s
  /// reported range. Only valid while [CameraStatus.ready].
  Future<void> setExposureCompensation(double ev) async {
    _requireStatus(CameraStatus.ready, 'setExposureCompensation');

    final clamped = capability.clampExposureCompensation(ev);
    try {
      await _platform.setExposureCompensation(clamped);
      _setValue(_value.copyWith(exposureCompensation: clamped));
    } on CustomCameraException catch (e) {
      _setValue(_value.copyWith(status: CameraStatus.error, lastError: e));
      rethrow;
    }
  }

  /// Unbinds the camera session and releases the platform resource.
  /// Safe to call from any state, including [CameraStatus.uninitialized]
  /// (no platform session was ever bound, so the platform is not called)
  /// or a repeated call after [CameraStatus.disposed] — all are a no-op,
  /// not an error.
  @override
  Future<void> dispose() async {
    if (_hasDisposed) return;
    _hasDisposed = true;

    final hadSession = _value.status != CameraStatus.uninitialized;

    if (_value.status != CameraStatus.disposing) {
      _setValue(_value.copyWith(status: CameraStatus.disposing));
    }

    if (hadSession) {
      await _platform.dispose();
      _platform.setEventListener(null);
      // Restores all four orientations -- undoes the portrait lock
      // applied in initialize(). Only done when a session actually
      // existed (hadSession), so a dispose() from CameraStatus.
      // uninitialized (a documented no-op, see this method's own docs)
      // never touches orientation preferences it never changed.
      await SystemChrome.setPreferredOrientations([]);
    }

    _setValue(_value.copyWith(status: CameraStatus.disposed, clearTextureId: true));
    super.dispose();
  }

  void _handlePlatformEvent(
    CameraPlatformEvent event,
    CameraPlatformError? error,
  ) {
    if (_value.status == CameraStatus.disposed ||
        _value.status == CameraStatus.disposing) {
      return;
    }

    final exception = switch (event) {
      CameraPlatformEvent.permissionRevoked =>
        const CameraPermissionDeniedException(
          'Camera permission was revoked while the session was active.',
        ),
      CameraPlatformEvent.disconnected => CameraDisconnectedException(
        error?.message ?? 'Camera was disconnected by the system.',
      ),
      CameraPlatformEvent.error => CameraInitializationException(
        error?.message ?? 'An unknown native camera error occurred.',
      ),
    };

    _setValue(_value.copyWith(status: CameraStatus.error, lastError: exception));
  }
}

CameraLensDirection _oppositeLens(CameraLensDirection lens) {
  switch (lens) {
    case CameraLensDirection.front:
      return CameraLensDirection.back;
    case CameraLensDirection.back:
      return CameraLensDirection.front;
  }
}
