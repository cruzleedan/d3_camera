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

// Preview. computePreviewContentRect is public because the annotation
// overlay must compute the *same* content rect the preview renders
// into -- sharing this one function is what keeps a mark where the user
// drew it, rather than two implementations drifting apart.
export 'src/preview/camera_preview_widget.dart';
export 'src/preview/preview_fit.dart';
export 'src/preview/preview_transform.dart';

// Ready-made UI. Three layers, from most to least turnkey:
//   D3CameraScreen -- a complete working camera screen
//   D3CameraScope  -- controller lifecycle handled, UI yours
//   the widgets below + CustomCameraPreview -- compose your own
// Each is built from the layer beneath it, so starting at the top costs
// nothing in flexibility later.
export 'src/ui/camera_control_buttons.dart';
export 'src/ui/camera_scope.dart';
export 'src/ui/camera_screen.dart';
export 'src/ui/capture_review_screen.dart';
export 'src/ui/zoom_level_bar.dart';

// Annotations. Geometry is always normalized [0,1] image space (see
// Coordinates below) so a mark drawn on a preview lands in the same
// place on a full-resolution export.
export 'src/annotations/annotation.dart';
export 'src/annotations/annotation_controller.dart';
export 'src/annotations/annotation_overlay_widget.dart';
export 'src/annotations/annotation_painter.dart';
export 'src/annotations/annotation_style.dart';
export 'src/annotations/annotation_tool.dart';
export 'src/annotations/hit_testing.dart';

// Coordinates
export 'src/coordinates/coordinate_space.dart';
export 'src/coordinates/normalized_point.dart';
export 'src/coordinates/normalized_rect.dart';

// Platform (exported so a consumer can supply a fake CameraPlatform in
// their own widget tests, same pattern this package's own tests use)
export 'src/platform/camera_platform_interface.dart';

// Errors
export 'src/errors/camera_exceptions.dart';
