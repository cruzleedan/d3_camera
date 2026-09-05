import 'package:d3_camera/d3_camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const D3CameraExampleApp());
}

/// Phase 1 functional demo: requests the camera permission, initializes
/// the controller, and displays the resulting state/capability. No
/// preview or capture yet -- this exists to prove the Pigeon contract
/// and CameraX session binding work end-to-end on a real device, per
/// WORK-0020's Definition of Done. The recommended integration pattern
/// this shows -- request permission via a plugin of the consuming app's
/// choice, then call initialize() -- is deliberate: d3_camera does not
/// take a permissions-plugin dependency itself (see CameraConfiguration/
/// CustomCameraController docs).
class D3CameraExampleApp extends StatelessWidget {
  const D3CameraExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('d3_camera example — Phase 1')),
        body: const _CameraFoundationDemo(),
      ),
    );
  }
}

class _CameraFoundationDemo extends StatefulWidget {
  const _CameraFoundationDemo();

  @override
  State<_CameraFoundationDemo> createState() => _CameraFoundationDemoState();
}

class _CameraFoundationDemoState extends State<_CameraFoundationDemo> {
  late final CustomCameraController _controller;
  String? _errorMessage;
  bool _permissionDenied = false;

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
      setState(() => _errorMessage = e.message);
    }
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Camera permission was denied. Grant it in system settings and '
            'restart the app to retry.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final state = _controller.value;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusRow(label: 'Status', value: state.status.name),
          _StatusRow(
            label: 'Active lens',
            value: state.activeLens?.name ?? '—',
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Error: $_errorMessage',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Controller error: ${state.lastError}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.capability case final capability?) ...[
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 8),
              child: Text(
                'Detected capability',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _StatusRow(
              label: 'Has flash',
              value: capability.hasFlash.toString(),
            ),
            _StatusRow(
              label: 'Zoom range',
              value:
                  '${capability.minZoomRatio.toStringAsFixed(1)}–'
                  '${capability.maxZoomRatio.toStringAsFixed(1)}',
            ),
            _StatusRow(
              label: 'Tap to focus',
              value: capability.supportsTapToFocus.toString(),
            ),
            _StatusRow(
              label: 'Exposure compensation',
              value: capability.supportsExposureCompensation
                  ? '${capability.minExposureCompensation.toStringAsFixed(1)}'
                        '–${capability.maxExposureCompensation.toStringAsFixed(1)} EV'
                  : 'not supported',
            ),
            _StatusRow(
              label: 'Available lenses',
              value: capability.availableLenses
                  .map((l) => l.name)
                  .join(', '),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
