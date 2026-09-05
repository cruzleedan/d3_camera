import 'package:flutter/material.dart';

import '../camera/aspect_ratio_preset.dart';
import '../camera/camera_configuration.dart';
import '../camera/camera_controller.dart';
import '../camera/camera_state.dart';
import '../camera/capture_result.dart';
import '../camera/flash_mode.dart';
import '../coordinates/normalized_point.dart';
import '../errors/camera_exceptions.dart';
import '../preview/camera_preview_widget.dart';
import 'camera_control_buttons.dart';
import 'camera_scope.dart';
import 'capture_review_screen.dart';
import 'zoom_level_bar.dart';

/// A complete, ready-to-use camera screen: live preview, shutter, zoom,
/// flash, aspect-ratio toggle, camera switch, tap-to-focus, and an
/// optional post-capture review.
///
/// This is the package's turnkey layer -- drop it in and you have a
/// working camera. It is built entirely from the same public primitives
/// a consumer can use directly ([CustomCameraPreview], [D3CameraScope],
/// [D3ShutterButton], and friends), so choosing it costs nothing in
/// flexibility later: when you outgrow it, compose your own screen from
/// those parts rather than fighting this one's options.
///
/// The controls follow where Pixel Camera and iOS Camera place theirs --
/// the feed in its own rect, never full-bleed behind floating buttons,
/// with zoom directly above the shutter and flash/ratio/switch below.
class D3CameraScreen extends StatefulWidget {
  const D3CameraScreen({
    super.key,
    this.configuration = const CameraConfiguration(),
    this.requestPermission,
    this.onCaptured,
    this.showReview = true,
    this.showAspectRatioToggle = true,
    this.showFlashToggle = true,
    this.showCameraSwitch = true,
    this.showZoomBar = true,
  });

  final CameraConfiguration configuration;

  /// See [CameraPermissionRequest]. When null, permission is assumed to
  /// have been granted already.
  final CameraPermissionRequest? requestPermission;

  /// Called with each capture. When [showReview] is true this fires
  /// after the user accepts the photo, so a rejected capture never
  /// reaches the consumer.
  final void Function(ImageCaptureResult capture)? onCaptured;

  /// Shows the captured photo for accept/retake before completing. When
  /// false, [onCaptured] fires immediately on capture.
  final bool showReview;

  final bool showAspectRatioToggle;
  final bool showFlashToggle;
  final bool showCameraSwitch;
  final bool showZoomBar;

  /// Pushes this screen and completes with the accepted capture, or null
  /// if the user backed out without taking one.
  ///
  /// A convenience for the common "go take a photo and come back with
  /// it" flow -- equivalent to pushing the widget yourself and reading
  /// the popped result.
  static Future<ImageCaptureResult?> show(
    BuildContext context, {
    CameraConfiguration configuration = const CameraConfiguration(),
    CameraPermissionRequest? requestPermission,
  }) {
    return Navigator.of(context).push<ImageCaptureResult>(
      MaterialPageRoute(
        builder: (context) => D3CameraScreen(
          configuration: configuration,
          requestPermission: requestPermission,
          onCaptured: (capture) => Navigator.of(context).pop(capture),
        ),
      ),
    );
  }

  @override
  State<D3CameraScreen> createState() => _D3CameraScreenState();
}

class _D3CameraScreenState extends State<D3CameraScreen> {
  ImageCaptureResult? _reviewingCapture;

  @override
  Widget build(BuildContext context) {
    return D3CameraScope(
      configuration: widget.configuration,
      requestPermission: widget.requestPermission,
      builder: (context, controller) {
        if (_reviewingCapture case final capture?) {
          return D3CaptureReviewScreen(
            capture: capture,
            onDismiss: () => setState(() => _reviewingCapture = null),
            onAccept: () {
              setState(() => _reviewingCapture = null);
              widget.onCaptured?.call(capture);
            },
          );
        }
        return _CameraScreenBody(
          controller: controller,
          config: widget,
          onCapture: (capture) {
            if (widget.showReview) {
              setState(() => _reviewingCapture = capture);
            } else {
              widget.onCaptured?.call(capture);
            }
          },
        );
      },
    );
  }
}

class _CameraScreenBody extends StatelessWidget {
  const _CameraScreenBody({
    required this.controller,
    required this.config,
    required this.onCapture,
  });

  final CustomCameraController controller;
  final D3CameraScreen config;
  final void Function(ImageCaptureResult capture) onCapture;

  Future<void> _capture(BuildContext context) async {
    try {
      final result = await controller.captureImage();
      if (!context.mounted) return;
      onCapture(result);
    } on CustomCameraException catch (e) {
      if (context.mounted) _showError(context, e.message);
    }
  }

  Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on CustomCameraException catch (e) {
      if (context.mounted) _showError(context, e.message);
    }
  }

  void _showError(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.value;
    final isReady = state.status == CameraStatus.ready;
    final capability = state.capability;

    // displayPreviewSize, not previewSize: the latter is sensor-space
    // (landscape on a portrait-held phone), which would give a 4:3 box
    // around 3:4 content and make the feed's proportions the reverse of
    // the captured image's.
    final displaySize = state.displayPreviewSize;
    final previewAspectRatio = displaySize == null
        ? 3 / 4
        : displaySize.width / displaySize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: previewAspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomCameraPreview(controller: controller),
                      if (capability?.supportsTapToFocus ?? false)
                        _TapToFocusLayer(
                          enabled: isReady,
                          onTap: (point) => _guard(
                            context,
                            () => controller.setMeteringPoint(point),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Control panel, entirely below the feed rect -- zoom
            // directly above the shutter, flash/ratio/switch below it,
            // matching where Pixel Camera and iOS Camera place them.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child:
                        config.showZoomBar &&
                            isReady &&
                            (capability?.maxZoomRatio ?? 1) > 1
                        ? D3ZoomLevelBar(controller: controller)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  D3ShutterButton(
                    onPressed: isReady ? () => _capture(context) : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (config.showFlashToggle)
                        D3FlashButton(
                          flashMode: state.flashMode,
                          onPressed: (isReady && (capability?.hasFlash ?? false))
                              ? () => _guard(
                                  context,
                                  () => controller.setFlashMode(
                                    _nextFlashMode(state.flashMode),
                                  ),
                                )
                              : null,
                        ),
                      if (config.showAspectRatioToggle) ...[
                        const SizedBox(width: 32),
                        D3AspectRatioButton(
                          aspectRatio: state.aspectRatio,
                          onPressed: isReady
                              ? () => _guard(
                                  context,
                                  () => controller.setAspectRatio(
                                    _nextAspectRatio(state.aspectRatio),
                                  ),
                                )
                              : null,
                        ),
                      ],
                      if (config.showCameraSwitch &&
                          (capability?.availableLenses.length ?? 0) > 1) ...[
                        const SizedBox(width: 32),
                        D3CameraControlButton(
                          icon: Icons.cameraswitch,
                          onPressed: isReady
                              ? () =>
                                    _guard(context, controller.switchCamera)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static FlashMode _nextFlashMode(FlashMode current) => switch (current) {
    FlashMode.off => FlashMode.on,
    FlashMode.on => FlashMode.auto,
    FlashMode.auto => FlashMode.off,
  };

  static AspectRatioPreset _nextAspectRatio(AspectRatioPreset current) =>
      switch (current) {
        AspectRatioPreset.ratio4x3 => AspectRatioPreset.ratio16x9,
        AspectRatioPreset.ratio16x9 => AspectRatioPreset.ratio4x3,
      };
}

/// Translates a tap anywhere on the preview into a normalized metering
/// point. Split out so the coordinate math lives in one place.
class _TapToFocusLayer extends StatelessWidget {
  const _TapToFocusLayer({required this.enabled, required this.onTap});

  final bool enabled;
  final void Function(NormalizedPoint point) onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: enabled
          ? (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final local = box.globalToLocal(details.globalPosition);
              onTap(
                NormalizedPoint(
                  (local.dx / box.size.width).clamp(0.0, 1.0),
                  (local.dy / box.size.height).clamp(0.0, 1.0),
                ),
              );
            }
          : null,
    );
  }
}
