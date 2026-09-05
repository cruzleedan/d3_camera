import 'dart:ui' show Size;

import 'package:meta/meta.dart';

import '../errors/camera_exceptions.dart';
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

  final FlashMode flashMode;
  final double zoomRatio;
  final double exposureCompensation;

  /// Non-null only when [status] is [CameraStatus.error].
  final CustomCameraException? lastError;

  CameraState copyWith({
    CameraStatus? status,
    CameraLensDirection? activeLens,
    CameraCapability? capability,
    int? textureId,
    bool clearTextureId = false,
    Size? previewSize,
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
    flashMode,
    zoomRatio,
    exposureCompensation,
    lastError,
  );

  @override
  String toString() =>
      'CameraState(status: $status, activeLens: $activeLens, '
      'capability: $capability, textureId: $textureId, '
      'previewSize: $previewSize, flashMode: $flashMode, '
      'zoomRatio: $zoomRatio, '
      'exposureCompensation: $exposureCompensation, lastError: $lastError)';
}
