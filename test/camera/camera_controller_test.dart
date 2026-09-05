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

  group('CustomCameraController.captureImage', () {
    test('transitions ready -> capturing -> ready and returns the result', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final statuses = <CameraStatus>[];
      controller.addListener(() => statuses.add(controller.value.status));

      final result = await controller.captureImage();

      expect(statuses, [CameraStatus.capturing, CameraStatus.ready]);
      expect(result, platform.captureResultToReturn);
      expect(platform.captureImageCallCount, 1);
    });

    test('throws InvalidCameraStateException if not ready', () async {
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: FakeCameraPlatform(),
      );
      addTearDown(controller.dispose);

      expect(
        () => controller.captureImage(),
        throwsA(isA<InvalidCameraStateException>()),
      );
    });

    test('a second concurrent call throws while the first is in flight', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final first = controller.captureImage();
      expect(
        () => controller.captureImage(),
        throwsA(isA<InvalidCameraStateException>()),
      );
      await first;
    });

    test('transitions to error and rethrows on platform failure', () async {
      final platform = FakeCameraPlatform(
        captureError: const CaptureFailedException('sensor busy'),
      );
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await expectLater(
        controller.captureImage(),
        throwsA(isA<CaptureFailedException>()),
      );
      expect(controller.value.status, CameraStatus.error);
    });
  });

  group('CustomCameraController.setFlashMode', () {
    test('updates state on success', () async {
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: FakeCameraPlatform(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.setFlashMode(FlashMode.on);

      expect(controller.value.flashMode, FlashMode.on);
    });

    test('throws InvalidCameraStateException if not ready', () async {
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: FakeCameraPlatform(),
      );
      addTearDown(controller.dispose);

      expect(
        () => controller.setFlashMode(FlashMode.on),
        throwsA(isA<InvalidCameraStateException>()),
      );
    });

    test('transitions to error when the device has no flash unit', () async {
      final platform = FakeCameraPlatform(
        setFlashModeError: const UnsupportedCapabilityException('flash'),
      );
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await expectLater(
        controller.setFlashMode(FlashMode.on),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
      expect(controller.value.status, CameraStatus.error);
    });
  });

  group('CustomCameraController.switchCamera', () {
    test('transitions ready -> switchingCamera -> ready, updates activeLens', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(
          initialLensDirection: CameraLensDirection.back,
        ),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final statuses = <CameraStatus>[];
      controller.addListener(() => statuses.add(controller.value.status));

      await controller.switchCamera();

      expect(statuses, [CameraStatus.switchingCamera, CameraStatus.ready]);
      expect(controller.value.activeLens, CameraLensDirection.front);
      expect(platform.lastSwitchTarget, CameraLensDirection.front);
    });

    test('switches to an explicit lens when provided', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(
          initialLensDirection: CameraLensDirection.back,
        ),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.switchCamera(to: CameraLensDirection.back);

      expect(platform.lastSwitchTarget, CameraLensDirection.back);
    });

    test('clears textureId while switching', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.value.textureId, isNotNull);

      int? textureIdDuringSwitch = -1;
      controller.addListener(() {
        if (controller.value.status == CameraStatus.switchingCamera) {
          textureIdDuringSwitch = controller.value.textureId;
        }
      });

      await controller.switchCamera();

      expect(textureIdDuringSwitch, isNull);
      expect(controller.value.textureId, isNotNull);
    });

    test('throws InvalidCameraStateException if not ready', () async {
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: FakeCameraPlatform(),
      );
      addTearDown(controller.dispose);

      expect(
        () => controller.switchCamera(),
        throwsA(isA<InvalidCameraStateException>()),
      );
    });
  });

  group('CustomCameraController.setZoom', () {
    test('clamps to the reported capability range before calling the platform', () async {
      final platform = FakeCameraPlatform(
        capabilityToReturn: const CameraCapability(
          hasFlash: true,
          minZoomRatio: 1,
          maxZoomRatio: 4,
          supportsTapToFocus: true,
          supportsExposureCompensation: true,
          minExposureCompensation: -2,
          maxExposureCompensation: 2,
          availableLenses: [CameraLensDirection.back],
        ),
      );
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.setZoom(10.0);

      expect(platform.lastZoomRatio, 4.0);
      expect(controller.value.zoomRatio, 4.0);
    });

    test('throws InvalidCameraStateException if not ready', () async {
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: FakeCameraPlatform(),
      );
      addTearDown(controller.dispose);

      expect(
        () => controller.setZoom(2.0),
        throwsA(isA<InvalidCameraStateException>()),
      );
    });
  });

  group('CustomCameraController.setExposureCompensation', () {
    test('clamps to the reported capability range before calling the platform', () async {
      final platform = FakeCameraPlatform(
        capabilityToReturn: const CameraCapability(
          hasFlash: true,
          minZoomRatio: 1,
          maxZoomRatio: 4,
          supportsTapToFocus: true,
          supportsExposureCompensation: true,
          minExposureCompensation: -2,
          maxExposureCompensation: 2,
          availableLenses: [CameraLensDirection.back],
        ),
      );
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.setExposureCompensation(5.0);

      expect(platform.lastExposureCompensation, 2.0);
      expect(controller.value.exposureCompensation, 2.0);
    });
  });

  group('CustomCameraController.setMeteringPoint', () {
    test('forwards the normalized point to the platform', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      const point = NormalizedPoint(0.3, 0.7);
      await controller.setMeteringPoint(point);

      expect(platform.lastMeteringPoint, point);
    });

    test('null resumes continuous focus/exposure', () async {
      final platform = FakeCameraPlatform();
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: platform,
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.setMeteringPoint(const NormalizedPoint(0.5, 0.5));
      await controller.setMeteringPoint(null);

      expect(platform.lastMeteringPoint, isNull);
    });

    test('throws InvalidCameraStateException if not ready', () async {
      final controller = CustomCameraController(
        configuration: const CameraConfiguration(),
        platform: FakeCameraPlatform(),
      );
      addTearDown(controller.dispose);

      expect(
        () => controller.setMeteringPoint(const NormalizedPoint(0.5, 0.5)),
        throwsA(isA<InvalidCameraStateException>()),
      );
    });
  });
}
