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
class _CustomUiDemo extends StatelessWidget {
  const _CustomUiDemo();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: D3CameraScope(
        requestPermission: _requestCameraPermission,
        builder: (context, controller) {
          final size = controller.value.displayPreviewSize;
          return Stack(
            fit: StackFit.expand,
            children: [
              // displayPreviewSize, not previewSize -- the latter is
              // sensor-space (landscape) and would frame the feed
              // sideways relative to the captured image.
              Center(
                child: AspectRatio(
                  aspectRatio: size == null ? 3 / 4 : size.width / size.height,
                  child: CustomCameraPreview(controller: controller),
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
