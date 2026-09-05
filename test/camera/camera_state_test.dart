import 'dart:ui' show Size;

import 'package:d3_camera/d3_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraState.displayPreviewSize', () {
    CameraState stateWith({Size? previewSize, int? sensorOrientationDegrees}) {
      return CameraState(
        status: CameraStatus.ready,
        previewSize: previewSize,
        sensorOrientationDegrees: sensorOrientationDegrees,
      );
    }

    test('swaps axes for a 90-degree sensor -- the real back-camera case', () {
      // The exact on-device case this getter exists for: a Pixel 10 back
      // camera reports SENSOR_ORIENTATION 90 and negotiates a landscape
      // 4000x3000 preview for a 4:3 session, but the feed is drawn
      // portrait. Sizing a box from previewSize gave a 4:3 landscape box
      // around 3:4 portrait content.
      final state = stateWith(
        previewSize: const Size(4000, 3000),
        sensorOrientationDegrees: 90,
      );

      expect(state.displayPreviewSize, const Size(3000, 4000));
      expect(state.displayPreviewSize!.width / state.displayPreviewSize!.height,
          closeTo(3 / 4, 1e-9));
    });

    test('swaps axes for a 270-degree sensor -- the front-camera case', () {
      final state = stateWith(
        previewSize: const Size(4000, 3000),
        sensorOrientationDegrees: 270,
      );

      expect(state.displayPreviewSize, const Size(3000, 4000));
    });

    test('leaves axes alone for a 0-degree sensor', () {
      final state = stateWith(
        previewSize: const Size(4000, 3000),
        sensorOrientationDegrees: 0,
      );

      expect(state.displayPreviewSize, const Size(4000, 3000));
    });

    test('leaves axes alone for a 180-degree sensor', () {
      final state = stateWith(
        previewSize: const Size(4000, 3000),
        sensorOrientationDegrees: 180,
      );

      expect(state.displayPreviewSize, const Size(4000, 3000));
    });

    test('is null before a session is bound', () {
      expect(const CameraState.initial().displayPreviewSize, isNull);
    });

    test('is null when the sensor orientation is unknown', () {
      final state = stateWith(previewSize: const Size(4000, 3000));

      expect(state.displayPreviewSize, isNull);
    });

    test('preserves a 16:9 session as 9:16 in display space', () {
      final state = stateWith(
        previewSize: const Size(1920, 1080),
        sensorOrientationDegrees: 90,
      );

      expect(state.displayPreviewSize, const Size(1080, 1920));
      expect(state.displayPreviewSize!.width / state.displayPreviewSize!.height,
          closeTo(9 / 16, 1e-9));
    });
  });
}
