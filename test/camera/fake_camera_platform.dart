import 'package:d3_camera/d3_camera.dart';

/// In-memory [CameraPlatform] fake for controller unit tests -- no real
/// hardware, no platform channel. Lets tests drive the state machine
/// directly and simulate native-initiated events via [emitEvent].
class FakeCameraPlatform implements CameraPlatform {
  FakeCameraPlatform({
    this.capabilityToReturn = const CameraCapability(
      hasFlash: true,
      minZoomRatio: 1,
      maxZoomRatio: 4,
      supportsTapToFocus: true,
      supportsExposureCompensation: true,
      minExposureCompensation: -2,
      maxExposureCompensation: 2,
      availableLenses: [CameraLensDirection.back, CameraLensDirection.front],
    ),
    this.initializeError,
  });

  /// Returned by [initialize] when [initializeError] is null.
  CameraCapability capabilityToReturn;

  /// When set, [initialize] throws this instead of succeeding.
  CustomCameraException? initializeError;

  int initializeCallCount = 0;
  int disposeCallCount = 0;
  CameraLensDirection? lastRequestedLensDirection;

  void Function(CameraPlatformEvent event, CameraPlatformError? error)?
  _listener;

  @override
  void setEventListener(
    void Function(CameraPlatformEvent event, CameraPlatformError? error)?
    listener,
  ) {
    _listener = listener;
  }

  /// Simulates a natively-initiated event, as if the OS reclaimed the
  /// camera or revoked the permission mid-session.
  void emitEvent(CameraPlatformEvent event, [CameraPlatformError? error]) {
    _listener?.call(event, error);
  }

  @override
  Future<CameraCapability> initialize(
    CameraLensDirection initialLensDirection,
  ) async {
    initializeCallCount++;
    lastRequestedLensDirection = initialLensDirection;
    final error = initializeError;
    if (error != null) throw error;
    return capabilityToReturn;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }
}
