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
  ImageCaptureResult? _lastCapture;

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
      setState(() => _lastCapture = result);
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

    final state = _controller.value;
    final isReady = state.status == CameraStatus.ready;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomCameraPreview(controller: _controller),

          if (!isReady && state.status != CameraStatus.capturing)
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: Text(
                  _setupError ?? state.lastError?.message ?? state.status.name,
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
                      final box = context.findRenderObject() as RenderBox;
                      final local = box.globalToLocal(details.globalPosition);
                      final point = NormalizedPoint(
                        (local.dx / box.size.width).clamp(0.0, 1.0),
                        (local.dy / box.size.height).clamp(0.0, 1.0),
                      );
                      _setMeteringPoint(point);
                    }
                  : null,
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ControlButton(
                        icon: switch (state.flashMode) {
                          FlashMode.off => Icons.flash_off,
                          FlashMode.on => Icons.flash_on,
                          FlashMode.auto => Icons.flash_auto,
                        },
                        onPressed: (isReady && (state.capability?.hasFlash ?? false))
                            ? _toggleFlash
                            : null,
                      ),
                      _ControlButton(
                        icon: Icons.cameraswitch,
                        onPressed: isReady ? _switchCamera : null,
                      ),
                    ],
                  ),
                  if (isReady && (state.capability?.maxZoomRatio ?? 1) > 1)
                    _ZoomSlider(controller: _controller),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ShutterButton(
                        onPressed: isReady ? _capture : null,
                      ),
                    ],
                  ),
                  if (_lastCapture case final capture?)
                    Text(
                      'Last capture: ${capture.width}x${capture.height} '
                      '(${capture.capturedLensDirection.name}) '
                      '@ ${capture.filePath}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
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

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({required this.controller});

  final CustomCameraController controller;

  @override
  Widget build(BuildContext context) {
    final capability = controller.capability;
    return Row(
      children: [
        const Icon(Icons.zoom_out, color: Colors.white70, size: 18),
        Expanded(
          child: Slider(
            value: controller.value.zoomRatio.clamp(
              capability.minZoomRatio,
              capability.maxZoomRatio,
            ),
            min: capability.minZoomRatio,
            max: capability.maxZoomRatio,
            onChanged: (value) => controller.setZoom(value),
          ),
        ),
        const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
      ],
    );
  }
}
