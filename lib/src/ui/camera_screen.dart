import 'package:flutter/material.dart';

import '../camera/aspect_ratio_preset.dart';
import '../camera/camera_configuration.dart';
import '../camera/camera_controller.dart';
import '../camera/camera_state.dart';
import '../camera/capture_result.dart';
import '../camera/flash_mode.dart';
import '../coordinates/normalized_point.dart';
import '../errors/camera_exceptions.dart';
import '../platform/camera_platform_interface.dart';
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
/// zoom directly above the shutter, flash/ratio/switch below it, all
/// overlaying the feed's lower edge. The feed itself keeps the full
/// screen width at every aspect ratio and grows downward as the ratio
/// gets taller, so switching 4:3 -> 16:9 shows *more*, not a smaller
/// letterboxed rect.
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
    this.enablePinchToZoom = true,
    @visibleForTesting this.platform,
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

  /// Pinch anywhere on the feed to zoom, in addition to the zoom bar's
  /// discrete steps. Independent of [showZoomBar] -- pinch alone is a
  /// reasonable setup when screen space is tight.
  final bool enablePinchToZoom;

  /// Injectable platform for tests; see [D3CameraScope.platform].
  @visibleForTesting
  final CameraPlatform? platform;

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
      // Forwarding this widget's own @visibleForTesting seam to the
      // scope's.
      // ignore: invalid_use_of_visible_for_testing_member
      platform: widget.platform,
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

    // Where the feed's bottom edge lands, so the controls can hug it.
    // At 16:9 the feed runs past the screen bottom and the controls stay
    // pinned to the screen; at 4:3 it ends partway down and the controls
    // ride up to sit on the feed rather than stranding the zoom bar in
    // the black band below it.
    final media = MediaQuery.of(context);
    final feedTop = media.padding.top;
    final feedHeight = media.size.width / previewAspectRatio;
    final feedBottom = feedTop + feedHeight;
    final bottomInset = (media.size.height - feedBottom).clamp(
      media.padding.bottom,
      double.infinity,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The feed is pinned to the full screen width and anchored to
          // the top, its height following the aspect ratio -- so
          // switching 4:3 -> 16:9 makes the feed *taller*, the way
          // native camera apps behave. Sizing it inside an Expanded +
          // Center instead would fit the available height, which shrinks
          // the width for taller ratios and reads as the feed getting
          // smaller when the user asked for more.
          // Only the top inset is honored: the feed clears the status
          // bar but keeps full width, and is free to run under the
          // bottom inset where the controls overlay it.
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Align(
              alignment: Alignment.topCenter,
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
                    if (config.enablePinchToZoom)
                      _PinchToZoomLayer(controller: controller),
                  ],
                ),
              ),
            ),
          ),

          // Controls overlay the feed's lower edge rather than sitting
          // in their own reserved strip, so the feed keeps full width at
          // every ratio -- zoom directly above the shutter, with
          // flash/ratio/switch below, matching Pixel and iOS Camera.
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
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
                            onPressed:
                                (isReady && (capability?.hasFlash ?? false))
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
                                ? () => _guard(context, controller.switchCamera)
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

/// Pinch-to-zoom over the preview.
///
/// Scales relative to the zoom ratio at gesture start rather than
/// accumulating per-update deltas, so a pinch that returns to its
/// starting spread returns to its starting zoom instead of drifting.
/// The controller clamps to the device's reported range, so this only
/// needs to pass the multiplied value through.
class _PinchToZoomLayer extends StatefulWidget {
  const _PinchToZoomLayer({required this.controller});

  final CustomCameraController controller;

  @override
  State<_PinchToZoomLayer> createState() => _PinchToZoomLayerState();
}

class _PinchToZoomLayerState extends State<_PinchToZoomLayer> {
  double _zoomAtGestureStart = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: (_) {
        _zoomAtGestureStart = widget.controller.value.zoomRatio;
      },
      onScaleUpdate: (details) {
        // A single-pointer drag also reports here with scale == 1;
        // ignoring it keeps taps and drags from nudging zoom and
        // stealing the tap-to-focus gesture.
        if (details.pointerCount < 2) return;
        // A pinch fires many updates a second, and setZoom throws if the
        // controller has left `ready` (a capture passes through
        // `capturing`). Skipping those, and swallowing the race where
        // status changes between this check and the call, keeps a
        // mid-gesture capture from raising an uncaught async error.
        if (widget.controller.value.status != CameraStatus.ready) return;
        widget.controller
            .setZoom(_zoomAtGestureStart * details.scale)
            .catchError((Object _) {});
      },
    );
  }
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
