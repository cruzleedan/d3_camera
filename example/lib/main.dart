import 'dart:io';

import 'package:d3_camera/d3_camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const D3CameraExampleApp());
}

/// Phase 2 functional demo: a full custom UI composed entirely from
/// package primitives, per the brief's own `Stack(preview, controls)`
/// composition -- no bundled camera screen exists in d3_camera itself.
/// Exercises preview, capture, flash, camera switch, zoom, and exposure
/// compensation on a physical device, per WORK-0021's incremental
/// verification plan. The recommended integration pattern shown here --
/// request permission via a plugin of the consuming app's own choice,
/// then call initialize() -- is deliberate: d3_camera does not take a
/// permissions-plugin dependency itself.
class D3CameraExampleApp extends StatelessWidget {
  const D3CameraExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: _CameraDemoScreen());
  }
}

class _CameraDemoScreen extends StatefulWidget {
  const _CameraDemoScreen();

  @override
  State<_CameraDemoScreen> createState() => _CameraDemoScreenState();
}

class _CameraDemoScreenState extends State<_CameraDemoScreen> {
  late final CustomCameraController _controller;
  String? _setupError;
  bool _permissionDenied = false;
  ImageCaptureResult? _reviewingCapture;

  @override
  void initState() {
    super.initState();
    _controller = CustomCameraController(
      configuration: const CameraConfiguration(),
    );
    _controller.addListener(_onControllerChanged);
    _requestPermissionAndInitialize();
  }

  void _onControllerChanged() => setState(() {});

  Future<void> _requestPermissionAndInitialize() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _permissionDenied = true);
      return;
    }

    try {
      await _controller.initialize();
    } on CustomCameraException catch (e) {
      setState(() => _setupError = e.message);
    }
  }

  Future<void> _capture() async {
    try {
      final result = await _controller.captureImage();
      if (!mounted) return;
      // A real camera app's own post-capture review screen -- replaces
      // the live camera view until the user dismisses it, rather than a
      // small thumbnail easy to miss.
      setState(() => _reviewingCapture = result);
    } on CustomCameraException catch (e) {
      _showError('Capture failed: ${e.message}');
    }
  }

  Future<void> _toggleFlash() async {
    final next = switch (_controller.value.flashMode) {
      FlashMode.off => FlashMode.on,
      FlashMode.on => FlashMode.auto,
      FlashMode.auto => FlashMode.off,
    };
    try {
      await _controller.setFlashMode(next);
    } on CustomCameraException catch (e) {
      _showError('Flash failed: ${e.message}');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } on CustomCameraException catch (e) {
      _showError('Switch failed: ${e.message}');
    }
  }

  Future<void> _toggleAspectRatio() async {
    final next = switch (_controller.value.aspectRatio) {
      AspectRatioPreset.ratio4x3 => AspectRatioPreset.ratio16x9,
      AspectRatioPreset.ratio16x9 => AspectRatioPreset.ratio4x3,
    };
    try {
      await _controller.setAspectRatio(next);
    } on CustomCameraException catch (e) {
      _showError('Aspect ratio change failed: ${e.message}');
    }
  }

  Future<void> _setMeteringPoint(NormalizedPoint point) async {
    try {
      await _controller.setMeteringPoint(point);
    } on CustomCameraException catch (e) {
      _showError('Focus failed: ${e.message}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Camera permission was denied. Grant it in system settings '
              'and restart the app to retry.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_reviewingCapture case final capture?) {
      return _CaptureReviewScreen(
        capture: capture,
        onDismiss: () => setState(() => _reviewingCapture = null),
      );
    }

    final state = _controller.value;
    final isReady = state.status == CameraStatus.ready;

    // Native Pixel/iOS camera apps don't run the feed full-bleed behind
    // floating controls -- the feed occupies a fixed rectangular area
    // (its own aspect ratio, letterboxed against the rest of the
    // screen), and shutter/zoom/flash/switch live below it in their own
    // dedicated space, never overlapping the image. displayPreviewSize's
    // own aspect ratio drives the box below rather than a hardcoded 4:3,
    // since it already reflects whatever CameraX actually negotiated
    // (see CameraXSession's AspectRatioStrategy, which keeps Preview and
    // ImageCapture on the same ratio).
    //
    // Note displayPreviewSize, not previewSize: the latter is sensor-space
    // (landscape) and would give a 4:3 box around 3:4 content, making the
    // feed's proportions the reverse of the captured image's.
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
                      CustomCameraPreview(controller: _controller),

                      if (!isReady && state.status != CameraStatus.capturing)
                        ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: Text(
                              _setupError ??
                                  state.lastError?.message ??
                                  state.status.name,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      if (state.capability?.supportsTapToFocus ?? false)
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: isReady
                              ? (details) {
                                  final box =
                                      context.findRenderObject() as RenderBox;
                                  final local = box.globalToLocal(
                                    details.globalPosition,
                                  );
                                  final point = NormalizedPoint(
                                    (local.dx / box.size.width).clamp(0.0, 1.0),
                                    (local.dy / box.size.height).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                  );
                                  _setMeteringPoint(point);
                                }
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Control panel, entirely below the feed rect -- zoom
            // directly above the shutter, flash/switch directly below
            // it, matching where Pixel Camera and iOS Camera place them.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child: isReady && (state.capability?.maxZoomRatio ?? 1) > 1
                        ? _ZoomLevelBar(controller: _controller)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _ShutterButton(onPressed: isReady ? _capture : null),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ControlButton(
                        icon: switch (state.flashMode) {
                          FlashMode.off => Icons.flash_off,
                          FlashMode.on => Icons.flash_on,
                          FlashMode.auto => Icons.flash_auto,
                        },
                        onPressed:
                            (isReady && (state.capability?.hasFlash ?? false))
                            ? _toggleFlash
                            : null,
                      ),
                      const SizedBox(width: 32),
                      _AspectRatioButton(
                        aspectRatio: state.aspectRatio,
                        onPressed: isReady ? _toggleAspectRatio : null,
                      ),
                      const SizedBox(width: 32),
                      _ControlButton(
                        icon: Icons.cameraswitch,
                        onPressed: isReady ? _switchCamera : null,
                      ),
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
}

/// Full-screen post-capture review -- the real capture-preview affordance
/// requested in on-device feedback (a capture with a shutter sound but no
/// visible result is a broken-feeling flow, not a minor polish item).
class _CaptureReviewScreen extends StatelessWidget {
  const _CaptureReviewScreen({required this.capture, required this.onDismiss});

  final ImageCaptureResult capture;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // Constrained to its own real aspect ratio via AspectRatio + BoxFit.
    // contain, rather than plain Image.file inside a bare Center --
    // Image.file with no explicit fit still scales to fill whatever
    // space its parent gives it, and an unconstrained Center in a full-
    // screen Stack hands it the *entire* screen height. Confirmed as a
    // real, measurable bug via on-device screenshots: the live feed's
    // own AspectRatio box was letterboxed to 1080x810 (a 4:3 ratio), but
    // this screen let the captured photo (the same 4:3 ratio, just
    // portrait-oriented at 3000x4000) fill the whole taller screen
    // instead, visibly showing more of the photo's vertical extent than
    // what was actually framed live -- the two need matching contain
    // behavior, not different available space to fit into.
    final captureAspectRatio = capture.width / capture.height;

    // This screen is swapped in by state rather than pushed as a route,
    // so there is nothing on the navigator stack for Android's back
    // gesture to pop -- without this, back closed the whole app instead
    // of returning to the capture screen. canPop: false claims the back
    // intent, and onPopInvokedWithResult routes it to the same dismiss
    // callback the close button uses, so gesture and button agree.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDismiss();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Center(
                child: AspectRatio(
                  aspectRatio: captureAspectRatio,
                  child: Image.file(
                    File(capture.filePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Column, not a bare Row: this sits in a StackFit.expand Stack,
            // so a Row here stretches to the full screen height and its
            // default centered cross-axis alignment parks both children
            // halfway down the screen, floating over the middle of the
            // photo. Pinning the close button to the top edge and the
            // metadata caption to the bottom keeps each anchored to a real
            // edge, the way a native review screen reads.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ControlButton(icon: Icons.close, onPressed: onDismiss),
                    const Spacer(),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${capture.width}x${capture.height} '
                          '(${capture.capturedLensDirection.name})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.white,
      disabledColor: Colors.white24,
      style: IconButton.styleFrom(backgroundColor: Colors.black45),
    );
  }
}

/// Toggles between 4:3 and 16:9 -- the two presets native camera apps
/// (Pixel Camera, iOS Camera) expose, both defaulting to 4:3. A text
/// label rather than an icon, since "4:3"/"16:9" isn't well represented
/// by a single glyph the way flash/switch are.
class _AspectRatioButton extends StatelessWidget {
  const _AspectRatioButton({
    required this.aspectRatio,
    required this.onPressed,
  });

  final AspectRatioPreset aspectRatio;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (aspectRatio) {
      AspectRatioPreset.ratio4x3 => '4:3',
      AspectRatioPreset.ratio16x9 => '16:9',
    };
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white24,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(12),
        minimumSize: const Size(48, 48),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onPressed == null ? Colors.white24 : Colors.white,
          border: Border.all(color: Colors.white70, width: 3),
        ),
      ),
    );
  }
}

/// A row of discrete zoom-level pills (1x, 2x, ...) rather than a bare
/// full-width Slider -- closer to how real camera apps present zoom, and
/// more usable via touch than dragging a thin slider thumb. Levels are
/// generated from the capability's own reported range rather than
/// hardcoded, since that range varies per device.
class _ZoomLevelBar extends StatelessWidget {
  const _ZoomLevelBar({required this.controller});

  final CustomCameraController controller;

  List<double> _levels(double min, double max) {
    final candidates = <double>{
      min,
      1.0,
      2.0,
      3.0,
      5.0,
      max,
    }.where((level) => level >= min && level <= max).toList()..sort();
    return candidates;
  }

  @override
  Widget build(BuildContext context) {
    final capability = controller.capability;
    final levels = _levels(capability.minZoomRatio, capability.maxZoomRatio);
    final current = controller.value.zoomRatio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final level in levels)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ZoomPill(
                label: level == level.roundToDouble()
                    ? '${level.toInt()}x'
                    : '${level.toStringAsFixed(1)}x',
                selected: (current - level).abs() < 0.05,
                onTap: () => controller.setZoom(level),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomPill extends StatelessWidget {
  const _ZoomPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
