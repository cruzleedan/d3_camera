import 'package:d3_camera/d3_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The review screen must use the space it is given. A portrait photo in
/// a landscape window previously rendered as a narrow column, because the
/// box was sized by available height alone -- the photo got *smaller*
/// when the screen got wider.
void main() {
  const capture = ImageCaptureResult(
    filePath: '/nonexistent/capture.jpg',
    width: 3000,
    height: 4000,
    exifOrientationDegrees: 0,
    capturedLensDirection: CameraLensDirection.back,
  );

  Future<Size> pumpAndMeasure(WidgetTester tester, Size screen) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: D3CaptureReviewScreen(capture: capture, onDismiss: () {}),
      ),
    );
    await tester.pump();

    // getSize would report the SizedBox's *logical* 3000x4000, before
    // FittedBox scales it. What matters is the size actually painted on
    // screen, so measure the global rect instead.
    return tester.getRect(find.byType(Image)).size;
  }

  testWidgets('a portrait photo fills the height in a portrait window', (
    tester,
  ) async {
    final size = await pumpAndMeasure(tester, const Size(1080, 2424));

    expect(size.width / size.height, closeTo(3000 / 4000, 1e-3));
    expect(size.width, closeTo(1080, 1),
        reason: 'width-limited in a narrow window');
  });

  testWidgets('a portrait photo scales up to use a landscape window', (
    tester,
  ) async {
    // The regression: 2424x1080 gave a 543x723 photo, using 22% of the
    // width. It should be height-limited instead, ~810x1080.
    final size = await pumpAndMeasure(tester, const Size(2424, 1080));

    expect(size.width / size.height, closeTo(3000 / 4000, 1e-3),
        reason: 'aspect ratio must be preserved');
    expect(size.height, greaterThan(900),
        reason: 'should be limited by height, not shrunk to fit a column');
    expect(size.width, greaterThan(700),
        reason: 'the old bug rendered this at ~543px wide');
  });

  testWidgets('the photo grows when the window gets wider, never shrinks', (
    tester,
  ) async {
    final portrait = await pumpAndMeasure(tester, const Size(1080, 2424));
    final landscape = await pumpAndMeasure(tester, const Size(2424, 1080));

    // Landscape is shorter, so the photo is necessarily smaller here --
    // what must not happen is it being smaller than the height allows.
    expect(landscape.height, closeTo(1080, 120),
        reason: 'should use nearly all the available height');
    expect(portrait.width, closeTo(1080, 1));
  });
}
