import 'dart:ui' show Size;

import 'package:meta/meta.dart';

import '../errors/camera_exceptions.dart';
import 'aspect_ratio_preset.dart';
import 'camera_capability.dart';
import 'flash_mode.dart';

/// The camera controller's lifecycle state.
///
/// `uninitialized → initializing → ready → disposing → disposed`, plus
/// `capturing` and `switchingCamera` (both re-entrant from and back to
/// `ready`) and `error`, reachable from any state.
enum CameraStatus {
  uninitialized,
  initializing,
  ready,
  capturing,
  switchingCamera,
  disposing,
  disposed,
  error,
}

/// Immutable snapshot of camera state, exposed via
/// `CustomCameraController.value`. Consumers read this to drive their own
/// UI — e.g. disable a shutter button outside [CameraStatus.ready] — and
/// are notified of changes via the controller's `ChangeNotifier` calls.
@immutable
class CameraState {
  const CameraState({
    required this.status,
    this.activeLens,
    this.capability,
    this.textureId,
    this.previewSize,
    this.sensorOrientationDegrees,
    this.aspectRatio = AspectRatioPreset.ratio4x3,
    this.flashMode = FlashMode.off,
    this.zoomRatio = 1.0,
    this.exposureCompensation = 0.0,
    this.lastError,
  });

  const CameraState.initial() : this(status: CameraStatus.uninitialized);

  final CameraStatus status;

  /// Null until the first successful `initialize()` call.
  final CameraLensDirection? activeLens;

  /// Null until the first successful `initialize()` call.
  final CameraCapability? capability;

  /// The Flutter texture id `CustomCameraPreview` reads to display the
  /// live feed. Null until the first successful `initialize()` call, and
  /// while [status] is [CameraStatus.switchingCamera] (the previous
  /// texture is no longer valid and the new one is not yet bound).
  final int? textureId;

  /// The bound preview's native resolution, for cover/contain layout.
  /// Null under the same conditions as [textureId].
  final Size? previewSize;

  /// `CameraCharacteristics.SENSOR_ORIENTATION` for [activeLens], in
  /// degrees. `CustomCameraPreview` uses this to correct the Texture's
  /// rotation on the Dart side — required because Flutter's
  /// SurfaceProducer texture path does not apply this correction itself
  /// on API 29+ devices. Null under the same conditions as [textureId].
  final int? sensorOrientationDegrees;

  /// The currently-bound preview/capture aspect ratio. Reflects
  /// `CameraConfiguration.initialAspectRatio` until changed via
  /// `CustomCameraController.setAspectRatio`.
  final AspectRatioPreset aspectRatio;

  final FlashMode flashMode;
  final double zoomRatio;
  final double exposureCompensation;

  /// Non-null only when [status] is [CameraStatus.error].
  final CustomCameraException? lastError;

  /// [previewSize] rotated into *display* space — the aspect ratio the
  /// feed actually occupies on screen once `CustomCameraPreview`'s
  /// rotation correction is applied.
  ///
  /// [previewSize] is the resolution CameraX negotiated in *sensor*
  /// space, which on a portrait-held phone is landscape (e.g. 4000x3000
  /// for a 4:3 session, since the sensor is mounted 90 degrees rotated).
  /// A consumer sizing its own box — an `AspectRatio` around the preview,
  /// say — needs the post-rotation dimensions instead, or it gets a
  /// landscape box around portrait content: the feed then renders 4:3
  /// while `captureImage()` returns a 3:4 image. Use this getter for any
  /// layout decision; use [previewSize] only when you specifically want
  /// the sensor-space resolution.
  ///
  /// Null under the same conditions as [previewSize].
  Size? get displayPreviewSize {
    final size = previewSize;
    final sensorDegrees = sensorOrientationDegrees;
    if (size == null || sensorDegrees == null) return null;
    // A 90/270-degree correction swaps which dimension reads as width.
    // Derived from the sensor angle alone (not the lens-direction sign)
    // because the sign only flips 90 <-> 270, and both swap alike.
    final swapsAxes = (sensorDegrees ~/ 90).isOdd;
    return swapsAxes ? Size(size.height, size.width) : size;
  }

  CameraState copyWith({
    CameraStatus? status,
    CameraLensDirection? activeLens,
    CameraCapability? capability,
    int? textureId,
    bool clearTextureId = false,
    Size? previewSize,
    int? sensorOrientationDegrees,
    AspectRatioPreset? aspectRatio,
    FlashMode? flashMode,
    double? zoomRatio,
    double? exposureCompensation,
    CustomCameraException? lastError,
    bool clearError = false,
  }) {
    return CameraState(
      status: status ?? this.status,
      activeLens: activeLens ?? this.activeLens,
      capability: capability ?? this.capability,
      textureId: clearTextureId ? null : (textureId ?? this.textureId),
      previewSize: clearTextureId ? null : (previewSize ?? this.previewSize),
      sensorOrientationDegrees: clearTextureId
          ? null
          : (sensorOrientationDegrees ?? this.sensorOrientationDegrees),
      aspectRatio: aspectRatio ?? this.aspectRatio,
      flashMode: flashMode ?? this.flashMode,
      zoomRatio: zoomRatio ?? this.zoomRatio,
      exposureCompensation: exposureCompensation ?? this.exposureCompensation,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          activeLens == other.activeLens &&
          capability == other.capability &&
          textureId == other.textureId &&
          previewSize == other.previewSize &&
          sensorOrientationDegrees == other.sensorOrientationDegrees &&
          aspectRatio == other.aspectRatio &&
          flashMode == other.flashMode &&
          zoomRatio == other.zoomRatio &&
          exposureCompensation == other.exposureCompensation &&
          lastError == other.lastError;

  @override
  int get hashCode => Object.hash(
    status,
    activeLens,
    capability,
    textureId,
    previewSize,
    sensorOrientationDegrees,
    aspectRatio,
    flashMode,
    zoomRatio,
    exposureCompensation,
    lastError,
  );

  @override
  String toString() =>
      'CameraState(status: $status, activeLens: $activeLens, '
      'capability: $capability, textureId: $textureId, '
      'previewSize: $previewSize, '
      'sensorOrientationDegrees: $sensorOrientationDegrees, '
      'aspectRatio: $aspectRatio, '
      'flashMode: $flashMode, zoomRatio: $zoomRatio, '
      'exposureCompensation: $exposureCompensation, lastError: $lastError)';
}
