import 'package:flutter/services.dart' show PlatformException;

import '../camera/camera_capability.dart';
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
  Future<CameraCapability> initialize(
    CameraLensDirection initialLensDirection,
  ) async {
    try {
      final data = await _hostApi.initialize(
        _toPigeonLensDirection(initialLensDirection),
      );
      return _fromPigeonCapability(data);
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _hostApi.dispose();
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

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
    default:
      return CameraInitializationException(
        e.message ?? 'Camera initialization failed (${e.code}).',
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
