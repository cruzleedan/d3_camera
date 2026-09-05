import 'package:meta/meta.dart';

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
  });

  final CameraLensDirection initialLensDirection;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraConfiguration &&
          runtimeType == other.runtimeType &&
          initialLensDirection == other.initialLensDirection;

  @override
  int get hashCode => initialLensDirection.hashCode;

  @override
  String toString() =>
      'CameraConfiguration(initialLensDirection: $initialLensDirection)';
}
