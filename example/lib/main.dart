import 'package:flutter/material.dart';

void main() {
  runApp(const D3CameraExampleApp());
}

/// Placeholder example app. Will grow into the `full_custom_ui` demo from
/// the design doc (§18) as the package's Phase 1/2 API lands.
class D3CameraExampleApp extends StatelessWidget {
  const D3CameraExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('d3_camera example')),
        body: const Center(child: Text('No functional example yet.')),
      ),
    );
  }
}
