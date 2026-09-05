import 'package:d3_camera/src/preview/preview_fit.dart';
import 'package:d3_camera/src/preview/preview_transform.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computePreviewContentRect — cover', () {
    test('content wider than widget: scales to widget height, overflows width', () {
      // 16:9 content in a 1:1 widget.
      final rect = computePreviewContentRect(
        widgetSize: const Size(400, 400),
        contentSize: const Size(1920, 1080),
        fit: PreviewFit.cover,
      );

      expect(rect.height, 400);
      expect(rect.width, closeTo(400 * (1920 / 1080), 0.001));
      // Centered horizontally: overflow split evenly on both sides.
      expect(rect.left, closeTo((400 - rect.width) / 2, 0.001));
      expect(rect.top, 0);
    });

    test('content taller than widget: scales to widget width, overflows height', () {
      // 9:16 (portrait) content in a 1:1 widget.
      final rect = computePreviewContentRect(
        widgetSize: const Size(400, 400),
        contentSize: const Size(1080, 1920),
        fit: PreviewFit.cover,
      );

      expect(rect.width, 400);
      expect(rect.height, closeTo(400 * (1920 / 1080), 0.001));
      expect(rect.left, 0);
      expect(rect.top, closeTo((400 - rect.height) / 2, 0.001));
    });

    test('identical aspect ratios: exactly fills the widget, no offset', () {
      final rect = computePreviewContentRect(
        widgetSize: const Size(800, 450),
        contentSize: const Size(1920, 1080),
        fit: PreviewFit.cover,
      );

      expect(rect, const Rect.fromLTWH(0, 0, 800, 450));
    });
  });

  group('computePreviewContentRect — contain', () {
    test('content wider than widget: scales to widget width, letterboxed top/bottom', () {
      final rect = computePreviewContentRect(
        widgetSize: const Size(400, 400),
        contentSize: const Size(1920, 1080),
        fit: PreviewFit.contain,
      );

      expect(rect.width, 400);
      expect(rect.height, closeTo(400 * (1080 / 1920), 0.001));
      expect(rect.left, 0);
      expect(rect.top, closeTo((400 - rect.height) / 2, 0.001));
    });

    test('content taller than widget: scales to widget height, letterboxed left/right', () {
      final rect = computePreviewContentRect(
        widgetSize: const Size(400, 400),
        contentSize: const Size(1080, 1920),
        fit: PreviewFit.contain,
      );

      expect(rect.height, 400);
      expect(rect.width, closeTo(400 * (1080 / 1920), 0.001));
      expect(rect.top, 0);
      expect(rect.left, closeTo((400 - rect.width) / 2, 0.001));
    });

    test('identical aspect ratios: exactly fills the widget, no offset', () {
      final rect = computePreviewContentRect(
        widgetSize: const Size(800, 450),
        contentSize: const Size(1920, 1080),
        fit: PreviewFit.contain,
      );

      expect(rect, const Rect.fromLTWH(0, 0, 800, 450));
    });
  });

  group('computePreviewContentRect — edge cases', () {
    test('zero-size widget does not divide by zero or throw', () {
      expect(
        () => computePreviewContentRect(
          widgetSize: Size.zero,
          contentSize: const Size(1920, 1080),
          fit: PreviewFit.cover,
        ),
        returnsNormally,
      );
    });

    test('zero-size content does not divide by zero or throw', () {
      expect(
        () => computePreviewContentRect(
          widgetSize: const Size(400, 400),
          contentSize: Size.zero,
          fit: PreviewFit.cover,
        ),
        returnsNormally,
      );
    });
  });

  group('computeRotationQuarterTurns', () {
    test(
      'back camera, sensor 90 degrees, portrait-up device: one quarter turn',
      () {
        // The exact case confirmed on a physical device (Pixel 10, rear
        // camera, SENSOR_ORIENTATION=90) where omitting this correction
        // produced a preview visibly rotated 90 degrees from upright.
        final turns = computeRotationQuarterTurns(
          sensorOrientationDegrees: 90,
          deviceOrientationDegrees: 0,
          sign: -1,
        );
        expect(turns, 1);
      },
    );

    test(
      'front camera, sensor 270 degrees, portrait-up device: three quarter turns',
      () {
        // SENSOR_ORIENTATION=270 for the front lens was confirmed via
        // dumpsys media.camera on the same physical device as the back-
        // camera case above, but -- unlike that case -- the resulting
        // *visual* correctness of this specific quarterTurns value has
        // not itself been independently confirmed on-device (only the
        // back camera's rotation bug was actually observed and fixed).
        // This test locks in the formula's output for this input; if
        // front-camera preview is later found visually wrong, revisit
        // the `sign` convention here first, per this function's own docs
        // on why front/back use opposite signs.
        final turns = computeRotationQuarterTurns(
          sensorOrientationDegrees: 270,
          deviceOrientationDegrees: 0,
          sign: 1,
        );
        expect(turns, 3);
      },
    );

    test('sensor orientation 0 degrees needs no correction', () {
      final turns = computeRotationQuarterTurns(
        sensorOrientationDegrees: 0,
        deviceOrientationDegrees: 0,
        sign: -1,
      );
      expect(turns, 0);
    });

    test('result is always in range 0..3', () {
      for (final sensorDegrees in [0, 90, 180, 270]) {
        for (final sign in [-1, 1]) {
          final turns = computeRotationQuarterTurns(
            sensorOrientationDegrees: sensorDegrees,
            deviceOrientationDegrees: 0,
            sign: sign,
          );
          expect(turns, inInclusiveRange(0, 3));
        }
      }
    });
  });
}
