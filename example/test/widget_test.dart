import 'package:flutter_test/flutter_test.dart';

import 'package:d3_camera_example/main.dart';

void main() {
  testWidgets('renders without crashing before permission resolves', (
    WidgetTester tester,
  ) async {
    // permission_handler has no platform implementation in a plain
    // widget test, so the permission request future never resolves --
    // this only verifies the initial frame (status: uninitialized, no
    // texture bound yet) builds without throwing. Real device behavior
    // (permission grant, initialize(), live preview, capture, controls)
    // is exercised on-device, not here -- see WORK-0021's Definition of
    // Done.
    await tester.pumpWidget(const D3CameraExampleApp());

    expect(find.text('uninitialized'), findsOneWidget);
  });
}
