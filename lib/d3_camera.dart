/// d3_camera: a customizable Flutter camera + image annotation package.
///
/// Public API surface only -- internal implementation lives under `src/`
/// and is not exported.
///
/// Phase 1 scope only: camera lifecycle (`CustomCameraController`,
/// `CameraConfiguration`, `CameraState`, `CameraCapability`) and the
/// typed exception hierarchy. Preview, capture, controls, and the
/// annotation system are not implemented yet -- their files exist as
/// named placeholders under `src/` but are not exported here until they
/// have real content, so the public API surface always matches what
/// actually works.
library;

// Camera
export 'src/camera/camera_capability.dart';
export 'src/camera/camera_configuration.dart';
export 'src/camera/camera_controller.dart';
export 'src/camera/camera_state.dart';

// Platform (exported so a consumer can supply a fake CameraPlatform in
// their own widget tests, same pattern this package's own tests use)
export 'src/platform/camera_platform_interface.dart';

// Errors
export 'src/errors/camera_exceptions.dart';
