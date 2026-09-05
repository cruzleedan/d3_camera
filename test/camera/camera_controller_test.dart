import 'package:d3_camera/d3_camera.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_camera_platform.dart';

void main() {
  group('CustomCameraController.initialize', () {
    test('transitions uninitialized -> initializing -> ready', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);

      expect(controller.value.status, CameraStatus.uninitialized);

      final statuses = <CameraStatus>[];
      controller.addListener(() => statuses.add(controller.value.status));

      await controller.initialize();

      expect(statuses, [CameraStatus.initializing, CameraStatus.ready]);
      expect(controller.value.status, CameraStatus.ready);
      expect(platform.initializeCallCount, 1);
    });

    test('requests the configured lens direction', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(
          initialLensDirection: CameraLensDirection.front,
        ),
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(platform.lastRequestedLensDirection, CameraLensDirection.front);
      expect(controller.value.activeLens, CameraLensDirection.front);
    });

    test('populates capability from the platform on success', () async {
      const capability = CameraCapability(
        hasFlash: false,
        minZoomRatio: 1,
        maxZoomRatio: 8,
        supportsTapToFocus: false,
        supportsExposureCompensation: true,
        minExposureCompensation: -3,
        maxExposureCompensation: 3,
        availableLenses: [CameraLensDirection.back],
      );
      final platform = FakeCameraPlatform(capabilityToReturn: capability);
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.value.capability, capability);
      expect(controller.capability, capability);
    });

    test('transitions to error and rethrows on platform failure', () async {
      final platform = FakeCameraPlatform(
        initializeError: const CameraPermissionDeniedException(),
      );
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);

      await expectLater(
        controller.initialize(),
        throwsA(isA<CameraPermissionDeniedException>()),
      );

      expect(controller.value.status, CameraStatus.error);
      expect(controller.value.lastError, isA<CameraPermissionDeniedException>());
    });

    test(
      'throws InvalidCameraStateException if called while already ready',
      () async {
        final controller = CustomCameraController(
          configuration: const CameraConfiguration(),
          platform: FakeCameraPlatform(),
        );
        addTearDown(controller.dispose);

        await controller.initialize();

        expect(
          () => controller.initialize(),
          throwsA(isA<InvalidCameraStateException>()),
        );
      },
    );

    test(
      'throws InvalidCameraStateException for a second concurrent call',
      () async {
        final controller = CustomCameraController(
          configuration: const CameraConfiguration(),
          platform: FakeCameraPlatform(),
        );
        addTearDown(controller.dispose);

        final first = controller.initialize();
        expect(
          () => controller.initialize(),
          throwsA(isA<InvalidCameraStateException>()),
        );
        await first;
      },
    );
  });

  group('CustomCameraController.dispose', () {
    test('transitions ready -> disposing -> disposed', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );

      await controller.initialize();

      final statuses = <CameraStatus>[];
      controller.addListener(() => statuses.add(controller.value.status));

      await controller.dispose();

      expect(statuses, [CameraStatus.disposing, CameraStatus.disposed]);
      expect(platform.disposeCallCount, 1);
    });

    test('is a no-op from uninitialized', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );

      await controller.dispose();

      expect(controller.value.status, CameraStatus.disposed);
      expect(platform.disposeCallCount, 0);
    });

    test('a second dispose() call is a no-op, not an error', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );

      await controller.initialize();
      await controller.dispose();
      await controller.dispose();

      expect(controller.value.status, CameraStatus.disposed);
      expect(platform.disposeCallCount, 1);
    });
  });

  group('CustomCameraController native events', () {
    test('permissionRevoked while ready transitions to error', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      platform.emitEvent(CameraPlatformEvent.permissionRevoked);

      expect(controller.value.status, CameraStatus.error);
      expect(
        controller.value.lastError,
        isA<CameraPermissionDeniedException>(),
      );
    });

    test('disconnected while ready transitions to error', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      platform.emitEvent(
        CameraPlatformEvent.disconnected,
        const CameraPlatformError(code: 'x', message: 'camera reclaimed'),
      );

      expect(controller.value.status, CameraStatus.error);
      expect(controller.value.lastError, isA<CameraDisconnectedException>());
    });

    test('an event after dispose() is ignored, not a crash', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );

      await controller.initialize();
      await controller.dispose();

      expect(
        () => platform.emitEvent(CameraPlatformEvent.disconnected),
        returnsNormally,
      );
    });
  });
}
