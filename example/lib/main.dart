import 'package:d3_camera/d3_camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const D3CameraExampleApp());
}

/// Demonstrates d3_camera's three layers of use, from turnkey to fully
/// custom. Each is built from the layer beneath it, so starting at the
/// top costs nothing in flexibility later.
///
/// Note what none of these do: request permission themselves. The
/// package takes no permissions-plugin dependency -- which one to use is
/// the app's choice -- so each entry point takes a callback. Here that
/// closes over `permission_handler`.
class D3CameraExampleApp extends StatelessWidget {
  const D3CameraExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const _HomeScreen(),
    );
  }
}

Future<bool> _requestCameraPermission() async =>
    (await Permission.camera.request()).isGranted;

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('d3_camera example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExampleTile(
            title: 'Turnkey screen',
            subtitle:
                'D3CameraScreen.show() -- one call, returns the capture. '
                'The whole camera in a single line.',
            onTap: () async {
              final capture = await D3CameraScreen.show(
                context,
                requestPermission: _requestCameraPermission,
              );
              if (context.mounted && capture != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Captured ${capture.width}x${capture.height}',
                    ),
                  ),
                );
              }
            },
          ),
          _ExampleTile(
            title: 'Embedded screen',
            subtitle:
                'The same screen with controls switched off and a capture '
                'callback, embedded in your own route.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _EmbeddedScreenDemo()),
            ),
          ),
          _ExampleTile(
            title: 'Custom UI',
            subtitle:
                'D3CameraScope hands you a ready controller; every pixel of '
                'the UI is yours.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _CustomUiDemo()),
            ),
          ),
          _ExampleTile(
            title: 'Annotate a photo',
            subtitle:
                'Capture, then mark it up. Geometry is normalized, so a '
                'mark lands in the same place on the full-resolution file.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _AnnotateDemo()),
            ),
          ),
        ],
      ),
    );
  }
}

/// The turnkey screen, minus the controls this app doesn't want, with
/// the capture handled inline rather than popped as a route result.
class _EmbeddedScreenDemo extends StatelessWidget {
  const _EmbeddedScreenDemo();

  @override
  Widget build(BuildContext context) {
    return D3CameraScreen(
      requestPermission: _requestCameraPermission,
      configuration: const CameraConfiguration(
        initialAspectRatio: AspectRatioPreset.ratio16x9,
      ),
      showAspectRatioToggle: false,
      showFlashToggle: false,
      onClose: () => Navigator.of(context).pop(),
      onCaptured: (capture) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Got ${capture.filePath}')),
        );
      },
    );
  }
}

/// The composable layer: D3CameraScope owns the controller's lifecycle
/// (permission, initialize, listen, dispose) and hands over a ready
/// controller, leaving the entire UI to us. This is the level the
/// package's own D3CameraScreen is built at.
class _CustomUiDemo extends StatefulWidget {
  const _CustomUiDemo();

  @override
  State<_CustomUiDemo> createState() => _CustomUiDemoState();
}

class _CustomUiDemoState extends State<_CustomUiDemo> {
  PreviewFit _fit = PreviewFit.cover;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: D3CameraScope(
        requestPermission: _requestCameraPermission,
        builder: (context, controller) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // A deliberately square box, not the feed's own aspect
              // ratio: cover and contain only differ when the box and
              // the content disagree, so this is what makes the fit
              // toggle below actually show something. Sizing the box to
              // displayPreviewSize (as D3CameraScreen does) makes the
              // two modes identical.
              Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: const Color(0xFF202020),
                    child: CustomCameraPreview(
                      controller: controller,
                      fit: _fit,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton(
                      onPressed: () => setState(() {
                        _fit = _fit == PreviewFit.cover
                            ? PreviewFit.contain
                            : PreviewFit.cover;
                      }),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('fit: ${_fit.name} (tap to toggle)'),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Entirely custom controls',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      D3ShutterButton(
                        onPressed: () async {
                          final capture = await controller.captureImage();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Captured ${capture.width}x${capture.height}',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExampleTile extends StatelessWidget {
  const _ExampleTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}


/// Capture a photo, then annotate it. The overlay shares the photo's own
/// AspectRatio box, so both resolve the same content rect -- which is
/// what keeps a mark on the feature the user drew it over.
class _AnnotateDemo extends StatefulWidget {
  const _AnnotateDemo();

  @override
  State<_AnnotateDemo> createState() => _AnnotateDemoState();
}

class _AnnotateDemoState extends State<_AnnotateDemo> {
  final _annotations = AnnotationController();
  ImageCaptureResult? _capture;
  AnnotationTool _tool = AnnotationTool.rectangle;

  @override
  void dispose() {
    _annotations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capture = _capture;
    if (capture == null) {
      return D3CameraScreen(
        requestPermission: _requestCameraPermission,
        showReview: false,
        onClose: () => Navigator.of(context).pop(),
        onCaptured: (result) => setState(() => _capture = result),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: D3CaptureReviewScreen(
              capture: capture,
              annotationController: _annotations,
              annotationTool: _tool,
              onDismiss: () => Navigator.of(context).pop(),
            ),
          ),
          _AnnotationToolbar(
            tool: _tool,
            controller: _annotations,
            onToolChanged: (t) => setState(() => _tool = t),
          ),
        ],
      ),
    );
  }
}

class _AnnotationToolbar extends StatelessWidget {
  const _AnnotationToolbar({
    required this.tool,
    required this.controller,
    required this.onToolChanged,
  });

  final AnnotationTool tool;
  final AnnotationController controller;
  final ValueChanged<AnnotationTool> onToolChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final t in AnnotationTool.values)
                  IconButton(
                    onPressed: () => onToolChanged(t),
                    color: t == tool ? Colors.amber : Colors.white70,
                    icon: Icon(switch (t) {
                      AnnotationTool.select => Icons.touch_app,
                      AnnotationTool.rectangle => Icons.crop_square,
                      AnnotationTool.circle => Icons.circle_outlined,
                      AnnotationTool.arrow => Icons.arrow_outward,
                      AnnotationTool.freehand => Icons.gesture,
                    }),
                  ),
                IconButton(
                  onPressed: controller.canUndo ? controller.undo : null,
                  color: Colors.white70,
                  disabledColor: Colors.white24,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  onPressed: controller.canRedo ? controller.redo : null,
                  color: Colors.white70,
                  disabledColor: Colors.white24,
                  icon: const Icon(Icons.redo),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
