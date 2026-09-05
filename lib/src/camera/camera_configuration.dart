import 'package:meta/meta.dart';

import 'aspect_ratio_preset.dart';
import 'camera_capability.dart';

/// Declarative startup intent for a `CustomCameraController` — what the
/// consumer wants, not what the device can do (that's
/// [CameraCapability], detected at init time). Immutable: to change
/// camera behavior mid-session, call a controller method rather than
/// mutating this object.
@immutable
class CameraConfiguration {
  const CameraConfiguration({
    this.initialLensDirection = CameraLensDirection.back,
    this.initialAspectRatio = AspectRatioPreset.ratio4x3,
  });

  final CameraLensDirection initialLensDirection;

  /// 4:3 by default, matching the native camera app convention this
  /// package's example follows. Change it live after `initialize()` via
  /// `CustomCameraController.setAspectRatio` — this field only controls
  /// the starting value.
  final AspectRatioPreset initialAspectRatio;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraConfiguration &&
          runtimeType == other.runtimeType &&
          initialLensDirection == other.initialLensDirection &&
          initialAspectRatio == other.initialAspectRatio;

  @override
  int get hashCode => Object.hash(initialLensDirection, initialAspectRatio);

  @override
  String toString() =>
      'CameraConfiguration(initialLensDirection: $initialLensDirection, '
      'initialAspectRatio: $initialAspectRatio)';
}
