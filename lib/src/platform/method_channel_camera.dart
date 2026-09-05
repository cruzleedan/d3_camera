import 'dart:ui' show Size;

import 'package:flutter/services.dart' show PlatformException;

import '../camera/camera_capability.dart';
import '../camera/capture_result.dart';
import '../camera/flash_mode.dart';
import '../coordinates/normalized_point.dart';
import '../errors/camera_exceptions.dart';
import 'camera_platform_interface.dart';
import 'pigeon/camera_api.g.dart' as pigeon;

/// Default [CameraPlatform] implementation, backed by the Pigeon-generated
/// `CameraHostApi`/`CameraFlutterApi`. This is the only file in the
/// package that imports `platform/pigeon/` directly — everything above
/// this layer talks to the [CameraPlatform] abstraction instead.
class MethodChannelCameraPlatform extends pigeon.CameraFlutterApi
    implements CameraPlatform {
  MethodChannelCameraPlatform({pigeon.CameraHostApi? hostApi})
    : _hostApi = hostApi ?? pigeon.CameraHostApi() {
    pigeon.CameraFlutterApi.setUp(this);
  }

  final pigeon.CameraHostApi _hostApi;
  void Function(CameraPlatformEvent event, CameraPlatformError? error)?
  _listener;

  @override
  void setEventListener(
    void Function(CameraPlatformEvent event, CameraPlatformError? error)?
    listener,
  ) {
    _listener = listener;
  }

  @override
  Future<CameraSessionInfo> initialize(
    CameraLensDirection initialLensDirection,
  ) => _guard(() async {
    final result = await _hostApi.initialize(
      _toPigeonLensDirection(initialLensDirection),
    );
    return _fromPigeonSessionInfo(
      result.capability,
      result.textureId,
      result.previewWidth,
      result.previewHeight,
    );
  });

  @override
  Future<void> dispose() => _guard(_hostApi.dispose);

  @override
  Future<ImageCaptureResult> captureImage() => _guard(() async {
    final result = await _hostApi.captureImage();
    return ImageCaptureResult(
      filePath: result.filePath,
      width: result.width,
      height: result.height,
      exifOrientationDegrees: result.exifOrientationDegrees,
      capturedLensDirection: _fromPigeonLensDirection(
        result.capturedLensDirection,
      ),
    );
  });

  @override
  Future<void> setFlashMode(FlashMode mode) =>
      _guard(() => _hostApi.setFlashMode(_toPigeonFlashMode(mode)));

  @override
  Future<CameraSessionInfo> switchCamera(CameraLensDirection lensDirection) =>
      _guard(() async {
        final result = await _hostApi.switchCamera(
          _toPigeonLensDirection(lensDirection),
        );
        return _fromPigeonSessionInfo(
          result.capability,
          result.textureId,
          result.previewWidth,
          result.previewHeight,
        );
      });

  @override
  Future<void> setZoom(double zoomRatio) =>
      _guard(() => _hostApi.setZoom(zoomRatio));

  @override
  Future<void> setMeteringPoint(NormalizedPoint? point) =>
      _guard(() => _hostApi.setMeteringPoint(_toPigeonPoint(point)));

  @override
  Future<void> setExposureCompensation(double ev) =>
      _guard(() => _hostApi.setExposureCompensation(ev));

  // pigeon.CameraFlutterApi override — called by the native side.
  @override
  void onCameraEvent(
    pigeon.NativeCameraEvent event,
    pigeon.CameraErrorData? error,
  ) {
    _listener?.call(
      _fromPigeonEvent(event),
      error == null
          ? null
          : CameraPlatformError(code: error.code, message: error.message),
    );
  }
}

/// Runs [body], translating any [PlatformException] into the typed
/// exception hierarchy. Centralized here so every `CameraHostApi` call
/// site gets the same mapping without repeating a try/catch.
Future<T> _guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on PlatformException catch (e) {
    throw _mapPlatformException(e);
  }
}

CustomCameraException _mapPlatformException(PlatformException e) {
  switch (e.code) {
    case 'permission_denied':
      return CameraPermissionDeniedException(
        e.message ?? 'Camera permission was denied.',
      );
    case 'camera_unavailable':
      return CameraUnavailableException(
        e.message ?? 'Camera is unavailable.',
      );
    case 'capability_unsupported':
      return UnsupportedCapabilityException(e.message ?? e.code);
    case 'capture_failed':
      return CaptureFailedException(
        e.message ?? 'Image capture failed.',
      );
    default:
      return CameraInitializationException(
        e.message ?? 'Camera operation failed (${e.code}).',
      );
  }
}

pigeon.LensDirection _toPigeonLensDirection(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.front:
      return pigeon.LensDirection.front;
    case CameraLensDirection.back:
      return pigeon.LensDirection.back;
  }
}

CameraLensDirection _fromPigeonLensDirection(pigeon.LensDirection direction) {
  switch (direction) {
    case pigeon.LensDirection.front:
      return CameraLensDirection.front;
    case pigeon.LensDirection.back:
      return CameraLensDirection.back;
  }
}

pigeon.FlashModeData _toPigeonFlashMode(FlashMode mode) {
  switch (mode) {
    case FlashMode.off:
      return pigeon.FlashModeData.off;
    case FlashMode.on:
      return pigeon.FlashModeData.on;
    case FlashMode.auto:
      return pigeon.FlashModeData.auto;
  }
}

pigeon.NormalizedPointData? _toPigeonPoint(NormalizedPoint? point) {
  if (point == null) return null;
  return pigeon.NormalizedPointData(x: point.x, y: point.y);
}

CameraCapability _fromPigeonCapability(pigeon.CameraCapabilityData data) {
  return CameraCapability(
    hasFlash: data.hasFlash,
    minZoomRatio: data.minZoomRatio,
    maxZoomRatio: data.maxZoomRatio,
    supportsTapToFocus: data.supportsTapToFocus,
    supportsExposureCompensation: data.supportsExposureCompensation,
    minExposureCompensation: data.minExposureCompensation,
    maxExposureCompensation: data.maxExposureCompensation,
    availableLenses: data.availableLenses
        .map(_fromPigeonLensDirection)
        .toList(growable: false),
  );
}

CameraSessionInfo _fromPigeonSessionInfo(
  pigeon.CameraCapabilityData capability,
  int textureId,
  int previewWidth,
  int previewHeight,
) {
  return CameraSessionInfo(
    capability: _fromPigeonCapability(capability),
    textureId: textureId,
    previewSize: Size(previewWidth.toDouble(), previewHeight.toDouble()),
  );
}

CameraPlatformEvent _fromPigeonEvent(pigeon.NativeCameraEvent event) {
  switch (event) {
    case pigeon.NativeCameraEvent.disconnected:
      return CameraPlatformEvent.disconnected;
    case pigeon.NativeCameraEvent.permissionRevoked:
      return CameraPlatformEvent.permissionRevoked;
    case pigeon.NativeCameraEvent.error:
      return CameraPlatformEvent.error;
  }
}
