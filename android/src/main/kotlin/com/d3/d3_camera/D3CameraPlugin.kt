package com.d3.d3_camera

import androidx.camera.core.ImageCapture
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers this plugin and implements [CameraHostApi] -- the Kotlin side
 * of the Pigeon contract. Delegates all actual CameraX work to
 * [CameraXSession]/[CameraCapabilityReader]/[ImageCaptureHandler]; this
 * class's own job is wiring the generated API to those collaborators and
 * translating failures into [FlutterError]s with stable codes the Dart
 * side maps onto its typed exception hierarchy.
 *
 * `CameraHostApi.setUp` (generated) already launches each call in its own
 * coroutine and catches any [Throwable] to relay back to Dart -- this
 * class's methods are plain `suspend fun`s that return a value or throw,
 * no manual callback/Result wiring needed.
 */
class D3CameraPlugin :
    FlutterPlugin,
    CameraHostApi {
    private var session: CameraXSession? = null
    private var flutterApi: CameraFlutterApi? = null
    private var cacheDir: java.io.File? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        session = CameraXSession(binding.applicationContext, binding.textureRegistry)
        flutterApi = CameraFlutterApi(binding.binaryMessenger)
        cacheDir = binding.applicationContext.cacheDir
        CameraHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        session?.unbind()
        session = null
        flutterApi = null
        cacheDir = null
        CameraHostApi.setUp(binding.binaryMessenger, null)
    }

    override suspend fun initialize(initialLensDirection: LensDirection): InitializeResult {
        val activeSession = requireSession()
        val bound = bindOrThrow(activeSession, initialLensDirection)
        return InitializeResult(
            capability =
                CameraCapabilityReader.read(bound.cameraInfo, activeSession.availableLensDirections()),
            textureId = bound.textureId,
            previewWidth = bound.previewWidth.toLong(),
            previewHeight = bound.previewHeight.toLong(),
        )
    }

    override suspend fun dispose() {
        session?.unbind()
    }

    override suspend fun captureImage(): CaptureResultData {
        val activeSession = requireSession()
        val dir =
            cacheDir
                ?: throw FlutterError("camera_unavailable", "Plugin is not attached.", null)
        try {
            val result = activeSession.captureImage(dir)
            return CaptureResultData(
                filePath = result.filePath,
                width = result.width.toLong(),
                height = result.height.toLong(),
                exifOrientationDegrees = result.exifOrientationDegrees.toLong(),
                capturedLensDirection = result.capturedLensDirection,
            )
        } catch (e: IllegalStateException) {
            throw FlutterError("camera_unavailable", e.message, null)
        } catch (e: Exception) {
            throw FlutterError("capture_failed", e.message ?: "Image capture failed.", null)
        }
    }

    override suspend fun setFlashMode(mode: FlashModeData) {
        val activeSession = requireSession()
        if (mode != FlashModeData.OFF && !activeSession.hasFlashUnit()) {
            throw FlutterError(
                "capability_unsupported",
                "The active lens has no flash unit.",
                null,
            )
        }
        activeSession.setFlashMode(
            when (mode) {
                FlashModeData.OFF -> ImageCapture.FLASH_MODE_OFF
                FlashModeData.ON -> ImageCapture.FLASH_MODE_ON
                FlashModeData.AUTO -> ImageCapture.FLASH_MODE_AUTO
            },
        )
    }

    override suspend fun switchCamera(lensDirection: LensDirection): SwitchCameraResult {
        val activeSession = requireSession()
        val bound = bindOrThrow(activeSession, lensDirection)
        return SwitchCameraResult(
            capability =
                CameraCapabilityReader.read(bound.cameraInfo, activeSession.availableLensDirections()),
            textureId = bound.textureId,
            previewWidth = bound.previewWidth.toLong(),
            previewHeight = bound.previewHeight.toLong(),
        )
    }

    override suspend fun setZoom(zoomRatio: Double) {
        requireSession().setZoomRatio(zoomRatio.toFloat())
    }

    override suspend fun setMeteringPoint(point: NormalizedPointData?) {
        val activeSession = requireSession()
        if (point == null) {
            activeSession.resumeContinuousFocus()
        } else {
            activeSession.setMeteringPoint(point.x.toFloat(), point.y.toFloat())
        }
    }

    override suspend fun setExposureCompensation(ev: Double) {
        // CameraX works in exposure-index steps, not raw EV -- the
        // caller (Dart) already clamps to the device's EV range, so the
        // conversion here only needs to invert CameraCapabilityReader's
        // own step-to-EV multiplication, not re-clamp.
        val activeSession = requireSession()
        val step = activeSession.exposureCompensationStep()
        val index = if (step == 0.0) 0 else Math.round(ev / step).toInt()
        activeSession.setExposureCompensationIndex(index)
    }

    private fun requireSession(): CameraXSession =
        session
            ?: throw FlutterError(
                "camera_unavailable",
                "Plugin is not attached to a Flutter engine.",
                null,
            )

    private suspend fun bindOrThrow(
        activeSession: CameraXSession,
        lensDirection: LensDirection,
    ): CameraXSession.BoundSession {
        try {
            return activeSession.bind(lensDirection)
        } catch (e: IllegalArgumentException) {
            throw FlutterError(
                "camera_unavailable",
                e.message ?: "No camera available for the requested lens direction.",
                null,
            )
        } catch (e: SecurityException) {
            throw FlutterError(
                "permission_denied",
                e.message ?: "Camera permission was denied.",
                null,
            )
        }
    }
}
