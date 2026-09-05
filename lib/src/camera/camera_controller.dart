import 'package:flutter/foundation.dart';

import '../errors/camera_exceptions.dart';
import '../platform/camera_platform_interface.dart';
import '../platform/method_channel_camera.dart';
import 'camera_capability.dart';
import 'camera_configuration.dart';
import 'camera_state.dart';

/// Owns the camera lifecycle and hardware state. The single object
/// consumers hold and pass to `CustomCameraPreview` and their own
/// controls.
///
/// Lifecycle: construct → [initialize] → used → [dispose]. Disposal is
/// mandatory and irreversible, matching Flutter's own controller
/// conventions (`TextEditingController`, `AnimationController`).
///
/// Every mutating method checks [value].status first. Calls made during a
/// transient state (`initializing`, `disposing`) throw
/// [InvalidCameraStateException] immediately rather than queuing —
/// queuing would hide bugs in consumer code that a loud failure surfaces
/// during development. Phase 1 exposes only [initialize] and [dispose];
/// capture/zoom/focus/exposure/switch methods are added once Phase 2
/// implements the use cases they depend on.
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

    try {
      final capability = await _platform.initialize(
        configuration.initialLensDirection,
      );
      _setValue(
        _value.copyWith(
          status: CameraStatus.ready,
          activeLens: configuration.initialLensDirection,
          capability: capability,
        ),
      );
    } on CustomCameraException catch (e) {
      _setValue(
        _value.copyWith(status: CameraStatus.error, lastError: e),
      );
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
    }

    _setValue(_value.copyWith(status: CameraStatus.disposed));
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
