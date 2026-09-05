/// d3_camera: a customizable Flutter camera + image annotation package.
///
/// Public API surface only -- internal implementation lives under `src/`
/// and is not exported. See the design doc (linked from README.md) for the
/// full architecture, phased plan, and rationale behind each decision.
library;

// Camera
export 'src/camera/camera_capability.dart';
export 'src/camera/camera_configuration.dart';
export 'src/camera/camera_controller.dart';
export 'src/camera/camera_state.dart';
export 'src/camera/capture_result.dart';

// Preview
export 'src/preview/camera_preview_widget.dart';

// Annotations
export 'src/annotations/annotation.dart';
export 'src/annotations/annotation_controller.dart';
export 'src/annotations/annotation_overlay_widget.dart';
export 'src/annotations/annotation_style.dart';

// Coordinates
export 'src/coordinates/normalized_rect.dart';

// Image / export
export 'src/image/export_options.dart';
export 'src/image/export_pipeline.dart';

// Errors
export 'src/errors/camera_exceptions.dart';
