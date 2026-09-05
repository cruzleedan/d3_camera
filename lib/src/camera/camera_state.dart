import 'package:meta/meta.dart';

import '../errors/camera_exceptions.dart';
import 'camera_capability.dart';

/// The camera controller's lifecycle state.
///
/// Phase 1 implements the subset reachable without capture/preview:
/// `uninitialized → initializing → ready → disposing → disposed`, plus
/// `error`, reachable from any state. `capturing` and `switchingCamera`
/// are part of the full design but have no transitions into them yet —
/// they're declared here so [CameraState.status]'s type doesn't need to
/// change shape again in Phase 2, but nothing in Phase 1 produces them.
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
    this.lastError,
  });

  const CameraState.initial() : this(status: CameraStatus.uninitialized);

  final CameraStatus status;

  /// Null until the first successful `initialize()` call.
  final CameraLensDirection? activeLens;

  /// Null until the first successful `initialize()` call.
  final CameraCapability? capability;

  /// Non-null only when [status] is [CameraStatus.error].
  final CustomCameraException? lastError;

  CameraState copyWith({
    CameraStatus? status,
    CameraLensDirection? activeLens,
    CameraCapability? capability,
    CustomCameraException? lastError,
    bool clearError = false,
  }) {
    return CameraState(
      status: status ?? this.status,
      activeLens: activeLens ?? this.activeLens,
      capability: capability ?? this.capability,
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
          lastError == other.lastError;

  @override
  int get hashCode =>
      Object.hash(status, activeLens, capability, lastError);

  @override
  String toString() =>
      'CameraState(status: $status, activeLens: $activeLens, '
      'capability: $capability, lastError: $lastError)';
}
