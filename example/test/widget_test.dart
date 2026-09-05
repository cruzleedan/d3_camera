import 'package:flutter_test/flutter_test.dart';

import 'package:d3_camera_example/main.dart';

void main() {
  testWidgets('renders the placeholder example app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const D3CameraExampleApp());

    expect(find.text('d3_camera example'), findsOneWidget);
  });
}
