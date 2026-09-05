import 'package:flutter/widgets.dart';

import '../camera/camera_capability.dart';
import '../camera/camera_controller.dart';
import '../camera/camera_state.dart';
import 'preview_fit.dart';
import 'preview_transform.dart';

/// The only widget that touches the platform texture. Displays
/// [controller]'s bound camera session as a live feed, laid out under
/// [fit] against the Texture's real (device-reported) aspect ratio.
///
/// Renders nothing (an empty [SizedBox]) before the controller reaches
/// [CameraStatus.ready] for the first time, or after
/// [CameraStatus.disposed] — there is deliberately no built-in loading
/// spinner or placeholder image, since the whole point of this package is
/// that the consuming app controls every pixel of its own UI; a consumer
/// wanting a placeholder composes one in the same `Stack`, behind this
/// widget, using `controller.value.status` to decide when to show it.
///
/// **Rotation correction.** On API 29+, Flutter's `Texture`/
/// `SurfaceProducer` rendering path does not automatically apply the
/// camera sensor's rotation metadata — confirmed on-device (see
/// `CameraSessionInfo.sensorOrientationDegrees`'s own docs for the full
/// story and the upstream Flutter issue this mirrors). This widget
/// corrects for it with a [RotatedBox], the same approach Flutter's own
/// official `camera_android_camerax` plugin uses. The device is currently
/// assumed to be held in the standard portrait-up orientation — this
/// package does not yet track live device-orientation changes (out of
/// Phase 2's scope), so rotating the physical device to landscape while
/// shooting is not yet compensated for.
///
/// Front-camera mirroring is applied here too, as a pure visual
/// transform — it affects only what's drawn on screen, never any
/// coordinate that might later be recorded against the captured image.
class CustomCameraPreview extends StatelessWidget {
  const CustomCameraPreview({
    super.key,
    required this.controller,
    this.fit = PreviewFit.cover,
  });

  final CustomCameraController controller;
  final PreviewFit fit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.value;
        final textureId = state.textureId;
        final previewSize = state.previewSize;
        final sensorOrientationDegrees = state.sensorOrientationDegrees;

        if (textureId == null ||
            previewSize == null ||
            sensorOrientationDegrees == null) {
          return const SizedBox.expand();
        }

        // Mirrors the formula Flutter's own official camera_android_camerax
        // plugin uses (flutter/packages#8629, RotatedPreview widget) --
        // see computeRotationQuarterTurns's own docs for the formula and
        // why it's needed. Device orientation assumed portraitUp (0
        // degrees) -- see this class's own doc comment on why that
        // assumption holds for now.
        final isFrontCamera = state.activeLens == CameraLensDirection.front;
        final quarterTurns = computeRotationQuarterTurns(
          sensorOrientationDegrees: sensorOrientationDegrees,
          deviceOrientationDegrees: 0,
          sign: isFrontCamera ? 1 : -1,
        );

        // computePreviewContentRect needs the *rotated* content
        // dimensions -- a 90/270-degree rotation swaps which of
        // previewSize's dimensions is width vs. height for layout
        // purposes, even though the Texture itself is still built at its
        // original, pre-rotation size (RotatedBox rotates the already-
        // laid-out child, it doesn't relayout it against swapped
        // constraints). This is exactly what CameraState.displayPreviewSize
        // exposes to consumers, so share it rather than recomputing --
        // the box a consumer lays out and the content drawn inside it
        // must agree on orientation.
        final rotatedContentSize = state.displayPreviewSize!;

        return LayoutBuilder(
          builder: (context, constraints) {
            final widgetSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final contentRect = computePreviewContentRect(
              widgetSize: widgetSize,
              contentSize: rotatedContentSize,
              fit: fit,
            );

            final texture = SizedBox(
              width: previewSize.width,
              height: previewSize.height,
              child: Texture(textureId: textureId),
            );
            final rotated = RotatedBox(quarterTurns: quarterTurns, child: texture);
            final mirrored = isFrontCamera
                ? Transform.flip(flipX: true, child: rotated)
                : rotated;

            return ClipRect(
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: contentRect,
                    child: FittedBox(fit: BoxFit.fill, child: mirrored),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
