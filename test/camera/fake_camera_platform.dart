import 'dart:ui' show Size;

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
    this.textureIdToReturn = 1,
    this.previewSizeToReturn = const Size(1920, 1080),
    this.sensorOrientationDegreesToReturn = 90,
    this.initializeError,
    this.captureResultToReturn = const ImageCaptureResult(
      filePath: '/fake/capture.jpg',
      width: 4032,
      height: 3024,
      exifOrientationDegrees: 0,
      capturedLensDirection: CameraLensDirection.back,
    ),
    this.captureError,
    this.setFlashModeError,
    this.switchCameraError,
  });

  /// Returned by [initialize]/[switchCamera] when their respective error
  /// fields are null.
  CameraCapability capabilityToReturn;
  int textureIdToReturn;
  Size previewSizeToReturn;
  int sensorOrientationDegreesToReturn;

  /// When set, [initialize] throws this instead of succeeding.
  CustomCameraException? initializeError;

  ImageCaptureResult captureResultToReturn;

  /// When set, [captureImage] throws this instead of succeeding.
  CustomCameraException? captureError;

  /// When set, [setFlashMode] throws this instead of succeeding.
  CustomCameraException? setFlashModeError;

  /// When set, [switchCamera] throws this instead of succeeding.
  CustomCameraException? switchCameraError;

  int initializeCallCount = 0;
  int disposeCallCount = 0;
  int captureImageCallCount = 0;
  int switchCameraCallCount = 0;
  CameraLensDirection? lastRequestedLensDirection;
  CameraLensDirection? lastSwitchTarget;
  FlashMode? lastFlashMode;
  double? lastZoomRatio;
  double? lastExposureCompensation;
  NormalizedPoint? lastMeteringPoint;

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
  Future<CameraSessionInfo> initialize(
    CameraLensDirection initialLensDirection,
  ) async {
    initializeCallCount++;
    lastRequestedLensDirection = initialLensDirection;
    final error = initializeError;
    if (error != null) throw error;
    return CameraSessionInfo(
      capability: capabilityToReturn,
      textureId: textureIdToReturn,
      previewSize: previewSizeToReturn,
      sensorOrientationDegrees: sensorOrientationDegreesToReturn,
    );
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }

  @override
  Future<ImageCaptureResult> captureImage() async {
    captureImageCallCount++;
    final error = captureError;
    if (error != null) throw error;
    return captureResultToReturn;
  }

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    lastFlashMode = mode;
    final error = setFlashModeError;
    if (error != null) throw error;
  }

  @override
  Future<CameraSessionInfo> switchCamera(
    CameraLensDirection lensDirection,
  ) async {
    switchCameraCallCount++;
    lastSwitchTarget = lensDirection;
    final error = switchCameraError;
    if (error != null) throw error;
    return CameraSessionInfo(
      capability: capabilityToReturn,
      textureId: textureIdToReturn,
      previewSize: previewSizeToReturn,
      sensorOrientationDegrees: sensorOrientationDegreesToReturn,
    );
  }

  @override
  Future<void> setZoom(double zoomRatio) async {
    lastZoomRatio = zoomRatio;
  }

  @override
  Future<void> setMeteringPoint(NormalizedPoint? point) async {
    lastMeteringPoint = point;
  }

  @override
  Future<void> setExposureCompensation(double ev) async {
    lastExposureCompensation = ev;
  }
}
