import 'package:d3_camera/d3_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../camera/fake_camera_platform.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // initialize()/dispose() lock orientation via SystemChrome, whose
  // platform channel never replies under test -- leaving the scope stuck
  // on its loading state forever. Answering the channel lets
  // initialize() complete so the ready UI actually builds.
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

  /// Pumps a ready D3CameraScreen backed by [platform] and settles the
  /// async initialize() the scope kicks off in initState.
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeCameraPlatform platform, {
    bool enablePinchToZoom = true,
    bool showZoomBar = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: D3CameraScreen(
          platform: platform,
          enablePinchToZoom: enablePinchToZoom,
          showZoomBar: showZoomBar,
        ),
      ),
    );
    // Not pumpAndSettle: the scope's loading state shows a
    // CircularProgressIndicator, whose animation never settles. Fixed
    // pumps let initialize() complete and the ready UI build.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('D3CameraScreen layout', () {
    testWidgets('feed spans the full width at 4:3', (tester) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Sensor-space 4:3, which displays as 3:4 portrait after the
      // 90-degree rotation correction.
      final platform = FakeCameraPlatform(
        previewSizeToReturn: const Size(4000, 3000),
        sensorOrientationDegreesToReturn: 90,
      );
      await pumpScreen(tester, platform);

      final feed = tester.getSize(find.byType(CustomCameraPreview));
      expect(feed.width, 1080, reason: 'feed must keep the full width');
      expect(feed.height, closeTo(1440, 1), reason: '3:4 of 1080');
    });

    testWidgets(
      'switching to 16:9 grows the height and keeps the full width',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2424);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // The bug this guards: sizing the feed inside Expanded + Center
        // fits the available *height*, so a taller ratio shrank the
        // width instead of growing the feed. Measured on-device as
        // 912x1621 where it should have been 1080x1920.
        final platform = FakeCameraPlatform(
          previewSizeToReturn: const Size(1920, 1080),
          sensorOrientationDegreesToReturn: 90,
        );
        await pumpScreen(tester, platform);

        final feed = tester.getSize(find.byType(CustomCameraPreview));
        expect(feed.width, 1080, reason: 'width must stay full-bleed');
        expect(feed.height, closeTo(1920, 1), reason: '9:16 of 1080');
      },
    );

    testWidgets('zoom bar overlays the feed rather than sitting below it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2424);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final platform = FakeCameraPlatform(
        previewSizeToReturn: const Size(4000, 3000),
        sensorOrientationDegreesToReturn: 90,
      );
      await pumpScreen(tester, platform);

      final feedRect = tester.getRect(find.byType(CustomCameraPreview));
      final zoomRect = tester.getRect(find.byType(D3ZoomLevelBar));
      expect(
        zoomRect.top,
        lessThan(feedRect.bottom),
        reason: 'zoom bar should sit on the feed, not under it',
      );
    });
  });

  group('D3CameraScreen pinch-to-zoom', () {
    testWidgets('a spread gesture zooms in', (tester) async {
      final platform = FakeCameraPlatform();
      await pumpScreen(tester, platform);
      expect(platform.lastZoomRatio, isNull);

      final center = tester.getCenter(find.byType(CustomCameraPreview));
      final g1 = await tester.startGesture(center - const Offset(40, 0));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      // Spread to roughly 2x the starting span.
      await g1.moveBy(const Offset(-40, 0));
      await g2.moveBy(const Offset(40, 0));
      await tester.pump();
      await g1.up();
      await g2.up();
      await tester.pump();

      expect(platform.lastZoomRatio, isNotNull);
      expect(
        platform.lastZoomRatio!,
        greaterThan(1.0),
        reason: 'spreading fingers should zoom in',
      );
    });

    testWidgets('a pinch gesture zooms back out', (tester) async {
      final platform = FakeCameraPlatform();
      await pumpScreen(tester, platform);

      final center = tester.getCenter(find.byType(CustomCameraPreview));
      // Start zoomed in so there is room to come back down.
      final g1 = await tester.startGesture(center - const Offset(80, 0));
      final g2 = await tester.startGesture(center + const Offset(80, 0));
      await g1.moveBy(const Offset(60, 0));
      await g2.moveBy(const Offset(-60, 0));
      await tester.pump();
      await g1.up();
      await g2.up();
      await tester.pump();

      // Clamped at the fake's minZoomRatio of 1.
      expect(platform.lastZoomRatio, isNotNull);
      expect(platform.lastZoomRatio!, lessThanOrEqualTo(1.0));
    });

    testWidgets('a single-finger drag does not change zoom', (tester) async {
      // Guards the tap-to-focus gesture: onScaleUpdate also fires for
      // one-pointer drags with scale == 1, which would otherwise nudge
      // zoom on every tap.
      final platform = FakeCameraPlatform();
      await pumpScreen(tester, platform);

      final center = tester.getCenter(find.byType(CustomCameraPreview));
      await tester.dragFrom(center, const Offset(0, -100));
      await tester.pump();

      expect(platform.lastZoomRatio, isNull);
    });

    testWidgets('no pinch layer when disabled', (tester) async {
      final platform = FakeCameraPlatform();
      await pumpScreen(tester, platform, enablePinchToZoom: false);

      final center = tester.getCenter(find.byType(CustomCameraPreview));
      final g1 = await tester.startGesture(center - const Offset(40, 0));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await g1.moveBy(const Offset(-40, 0));
      await g2.moveBy(const Offset(40, 0));
      await tester.pump();
      await g1.up();
      await g2.up();
      await tester.pump();

      expect(platform.lastZoomRatio, isNull);
    });
  });
}
