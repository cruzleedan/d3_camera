import 'package:d3_camera/d3_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../camera/fake_camera_platform.dart';

/// Front-camera preview must be mirrored on screen (users expect a
/// mirror, not a rear-facing view of themselves); the back camera must
/// not be. The flip is a pure visual transform in
/// `CustomCameraPreview` -- it deliberately never touches the captured
/// image or any coordinate recorded against it.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  /// The horizontal scale the preview applies to its texture. -1 means
  /// mirrored, 1 means not. Read off the actual render tree rather than
  /// asserting on widget types, so this keeps testing the real
  /// behaviour if the implementation changes shape.
  double horizontalScaleOf(WidgetTester tester) {
    final transforms = tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(CustomCameraPreview),
            matching: find.byType(Transform),
          ),
        )
        .toList();
    // Compose every Transform's x-scale; a flip contributes -1.
    var scale = 1.0;
    for (final t in transforms) {
      scale *= t.transform.storage[0];
    }
    return scale;
  }

  Future<CustomCameraController> pumpPreview(
    WidgetTester tester,
    FakeCameraPlatform platform, {
    required CameraLensDirection lens,
  }) async {
    final controller = CustomCameraController(
      configuration: CameraConfiguration(initialLensDirection: lens),
      platform: platform,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 600,
          child: CustomCameraPreview(controller: controller),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('front camera preview is mirrored', (tester) async {
    final platform = FakeCameraPlatform(sensorOrientationDegreesToReturn: 270);
    await pumpPreview(
      tester,
      platform,
      lens: CameraLensDirection.front,
    );

    expect(
      horizontalScaleOf(tester),
      lessThan(0),
      reason: 'front preview must be flipped horizontally',
    );
  });

  testWidgets('back camera preview is not mirrored', (tester) async {
    final platform = FakeCameraPlatform(sensorOrientationDegreesToReturn: 90);
    await pumpPreview(
      tester,
      platform,
      lens: CameraLensDirection.back,
    );

    expect(
      horizontalScaleOf(tester),
      greaterThan(0),
      reason: 'back preview must not be flipped',
    );
  });

  testWidgets('mirroring does not alter the reported preview size', (
    tester,
  ) async {
    // A flip must not change layout -- only what is drawn. Guards
    // against someone "fixing" mirroring by swapping dimensions.
    final platform = FakeCameraPlatform(
      previewSizeToReturn: const Size(4000, 3000),
      sensorOrientationDegreesToReturn: 270,
    );
    final controller = await pumpPreview(
      tester,
      platform,
      lens: CameraLensDirection.front,
    );

    expect(controller.value.displayPreviewSize, const Size(3000, 4000));
  });
}
