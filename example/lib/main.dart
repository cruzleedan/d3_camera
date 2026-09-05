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

  Future<void> _setMeteringPoint(NormalizedPoint point) async {
    try {
      await _controller.setMeteringPoint(point);
    } on CustomCameraException catch (e) {
      _showError('Focus failed: ${e.message}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    // dedicated space, never overlapping the image. previewSize's own
    // aspect ratio drives the box below rather than a hardcoded 4:3,
    // since it already reflects whatever CameraX actually negotiated
    // (see CameraXSession's AspectRatioStrategy, which keeps Preview and
    // ImageCapture on the same ratio).
    final previewAspectRatio = state.previewSize == null
        ? 3 / 4
        : state.previewSize!.width / state.previewSize!.height;

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
                                    (local.dy / box.size.height).clamp(0.0, 1.0),
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
                      const SizedBox(width: 48),
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: Image.file(File(capture.filePath))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ControlButton(icon: Icons.close, onPressed: onDismiss),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${capture.width}x${capture.height} '
                      '(${capture.capturedLensDirection.name})',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    final candidates = <double>{min, 1.0, 2.0, 3.0, 5.0, max}
        .where((level) => level >= min && level <= max)
        .toList()
      ..sort();
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
