/// d3_camera: a customizable Flutter camera + image annotation package.
///
/// Public API surface only -- internal implementation lives under `src/`
/// and is not exported.
///
/// Phase 2 scope: camera lifecycle, live preview, still capture, and
/// flash/zoom/focus/exposure/switch controls. The annotation system is
/// not implemented yet -- its files exist as named placeholders under
/// `src/` but are not exported here until they have real content, so the
/// public API surface always matches what actually works.
library;

// Camera
export 'src/camera/aspect_ratio_preset.dart';
export 'src/camera/camera_capability.dart';
export 'src/camera/camera_configuration.dart';
export 'src/camera/camera_controller.dart';
export 'src/camera/camera_state.dart';
export 'src/camera/capture_result.dart';
export 'src/camera/flash_mode.dart';

// Preview
export 'src/preview/camera_preview_widget.dart';
export 'src/preview/preview_fit.dart';

// Coordinates
export 'src/coordinates/normalized_point.dart';

// Platform (exported so a consumer can supply a fake CameraPlatform in
// their own widget tests, same pattern this package's own tests use)
export 'src/platform/camera_platform_interface.dart';

// Errors
export 'src/errors/camera_exceptions.dart';
