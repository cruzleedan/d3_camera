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
/// Front-camera mirroring is applied here, as a pure visual transform —
/// it affects only what's drawn on screen, never any coordinate that
/// might later be recorded against the captured image.
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

        if (textureId == null || previewSize == null) {
          return const SizedBox.expand();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final widgetSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final contentRect = computePreviewContentRect(
              widgetSize: widgetSize,
              contentSize: previewSize,
              fit: fit,
            );

            final texture = Texture(textureId: textureId);
            final mirrored = state.activeLens == CameraLensDirection.front
                ? Transform.flip(flipX: true, child: texture)
                : texture;

            return ClipRect(
              child: Stack(
                children: [Positioned.fromRect(rect: contentRect, child: mirrored)],
              ),
            );
          },
        );
      },
    );
  }
}
