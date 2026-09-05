package com.d3.d3_camera

import android.content.Context
import androidx.camera.core.CameraControl
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.FocusMeteringResult
import androidx.camera.core.ImageCapture
import androidx.camera.core.MeteringPointFactory
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceOrientedMeteringPointFactory
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import io.flutter.view.TextureRegistry
import kotlin.coroutines.resume
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Owns a single CameraX session: binding Preview + ImageCapture, exposing
 * zoom/focus/exposure/flash controls, and switching lenses. Also owns the
 * Flutter [TextureRegistry.SurfaceProducer] the bound Preview publishes
 * frames to.
 *
 * Bound to [ProcessLifecycleOwner] -- the whole application's foreground/
 * background lifecycle -- rather than a Flutter [android.app.Activity].
 * This is a deliberate design choice carried over from Phase 1: an
 * Activity-bound session would tie this plugin to `ActivityAware` and
 * break the moment a consuming app hosts the camera in something other
 * than a single-Activity Flutter setup. [ProcessLifecycleOwner] already
 * tracks app-level foreground/background transitions, and CameraX itself
 * unbinds/rebinds Preview on lifecycle STOP/START, so backgrounding the
 * app releases the camera without this class polling for it.
 */
class CameraXSession(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: androidx.camera.core.Camera? = null
    private var preview: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var boundLensDirection: LensDirection? = null
    private val lifecycleOwner: LifecycleOwner = ProcessLifecycleOwner.get()

    /** Result of a successful [bind]: the bound camera, its preview's resolution, and sensor orientation. */
    data class BoundSession(
        val cameraInfo: CameraInfo,
        val textureId: Long,
        val previewWidth: Int,
        val previewHeight: Int,
        val sensorOrientationDegrees: Int,
    )

    /**
     * Binds Preview and ImageCapture use cases for [lensDirection] and
     * publishes the preview to a newly created Flutter texture. Throws
     * [IllegalArgumentException] (surfaced by CameraX itself) if no
     * camera matches [lensDirection].
     */
    suspend fun bind(lensDirection: LensDirection): BoundSession {
        val provider = getOrCreateProvider()
        cameraProvider = provider

        surfaceProducer?.release()
        val producer = textureRegistry.createSurfaceProducer()
        surfaceProducer = producer

        val selector = selectorFor(lensDirection)

        // targetRotation deliberately left at CameraX's own default
        // (effectively ROTATION_0) rather than guessed from
        // DisplayManager, which this non-Activity-bound session has no
        // reliable reading for anyway. This is not where rotation
        // correctness comes from: on API 29+, Flutter's ImageReader-
        // backed SurfaceProducer texture path does not automatically
        // apply rotation/crop metadata regardless of what targetRotation
        // says (see TextureRegistry.SurfaceProducer#handlesCropAndRotation
        // and flutter/flutter#154241 -- confirmed on-device: a native-
        // side targetRotation fix alone did not resolve a real 90-degree
        // rotation). The actual fix mirrors Flutter's own official
        // camera_android_camerax plugin (flutter/packages#8629): correct
        // for CameraCharacteristics.SENSOR_ORIENTATION on the Dart side,
        // in CustomCameraPreview, via a RotatedBox. That's why this
        // method reports sensorOrientationDegrees in its result instead
        // of trying to solve rotation natively.
        val newPreview = Preview.Builder().build()
        val newImageCapture = ImageCapture.Builder().build()

        // CameraX invokes the SurfaceProvider asynchronously, on its own
        // executor, some milliseconds after bindToLifecycle returns --
        // NOT synchronously as part of it. bind() must actually suspend
        // until that callback fires, or callers (the Pigeon host API
        // handler) receive a resolution of 0x0 and CustomCameraPreview
        // can never compute correct cover/contain layout. Confirmed via
        // on-device logging: bindToLifecycle returned at t=58.641 in one
        // trace, but the SurfaceProvider callback didn't fire until
        // t=58.649 -- an 8ms gap that silently produced a black preview
        // before this fix.
        val resolution =
            suspendCancellableCoroutine<android.util.Size> { continuation ->
                newPreview.surfaceProvider = Preview.SurfaceProvider { request ->
                    val requestedResolution = request.resolution
                    producer.setSize(requestedResolution.width, requestedResolution.height)
                    request.provideSurface(producer.getSurface(), directExecutor()) {}
                    if (continuation.isActive) {
                        continuation.resume(requestedResolution)
                    }
                }

                provider.unbindAll()
                val boundCamera =
                    provider.bindToLifecycle(lifecycleOwner, selector, newPreview, newImageCapture)

                camera = boundCamera
                preview = newPreview
                imageCapture = newImageCapture
                boundLensDirection = lensDirection
            }

        return BoundSession(
            cameraInfo = camera!!.cameraInfo,
            textureId = producer.id(),
            previewWidth = resolution.width,
            previewHeight = resolution.height,
            sensorOrientationDegrees = sensorOrientationDegrees(camera!!.cameraInfo),
        )
    }

    private fun sensorOrientationDegrees(cameraInfo: CameraInfo): Int {
        val characteristic =
            androidx.camera.camera2.interop.Camera2CameraInfo
                .from(cameraInfo)
                .getCameraCharacteristic(android.hardware.camera2.CameraCharacteristics.SENSOR_ORIENTATION)
        return characteristic ?: 0
    }

    /** Unbinds all use cases and releases the Flutter texture. Safe to call even if never bound. */
    fun unbind() {
        cameraProvider?.unbindAll()
        surfaceProducer?.release()
        surfaceProducer = null
        camera = null
        preview = null
        imageCapture = null
        boundLensDirection = null
    }

    /** Which lens directions have at least one matching camera on this device. */
    fun availableLensDirections(): List<LensDirection> {
        val provider = cameraProvider ?: return emptyList()
        val available = mutableListOf<LensDirection>()
        if (provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) {
            available.add(LensDirection.BACK)
        }
        if (provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) {
            available.add(LensDirection.FRONT)
        }
        return available
    }

    suspend fun captureImage(cacheDir: java.io.File): ImageCaptureHandler.Result {
        val capture =
            imageCapture ?: throw IllegalStateException("No camera session is bound.")
        val lens =
            boundLensDirection ?: throw IllegalStateException("No camera session is bound.")
        return ImageCaptureHandler.capture(capture, cacheDir, lens)
    }

    fun setFlashMode(mode: Int) {
        imageCapture?.flashMode = mode
    }

    fun setZoomRatio(zoomRatio: Float) {
        camera?.cameraControl?.setZoomRatio(zoomRatio)
    }

    /**
     * Triggers autofocus AND auto-exposure metering together at ([x], [y])
     * in one [FocusMeteringAction] -- the standard tap-to-focus gesture.
     * Deliberately one `startFocusAndMetering` call, not two: CameraX
     * cancels an in-flight call when a second one starts on the same
     * camera, so separate AF-only and AE-only calls for the same tap
     * reliably race each other and surface as a cancellation exception.
     *
     * A second, *legitimate* source of cancellation remains even with a
     * single combined call: the user tapping a new point (or the same
     * point twice in quick succession) before the previous
     * `startFocusAndMetering` finishes. CameraX cancels the older call in
     * that case and completes its future exceptionally with
     * [CameraControl.OperationCanceledException] -- confirmed on-device
     * as the exact cause of a real crash report ("Cancelled by another
     * startFocusAndMetering()"). This is normal, expected behavior for a
     * tap-to-focus gesture (the newer tap simply supersedes the older
     * one), not a failure, so it is caught here and swallowed rather than
     * propagated as an error that would otherwise push the whole
     * controller into its error state over what the user experiences as
     * "I tapped focus twice."
     */
    suspend fun setMeteringPoint(x: Float, y: Float): FocusMeteringResult? {
        val cameraControl = camera?.cameraControl ?: return null
        val factory = meteringPointFactory() ?: return null
        val point = factory.createPoint(x, y)
        val action =
            FocusMeteringAction.Builder(point, FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE)
                .build()
        return try {
            cameraControl.startFocusAndMetering(action).await()
        } catch (e: CameraControl.OperationCanceledException) {
            null
        }
    }

    fun resumeContinuousFocus() {
        camera?.cameraControl?.cancelFocusAndMetering()
    }

    fun setExposureCompensationIndex(index: Int) {
        camera?.cameraControl?.setExposureCompensationIndex(index)
    }

    fun hasFlashUnit(): Boolean = camera?.cameraInfo?.hasFlashUnit() ?: false

    /** EV per exposure-compensation index step, or 0.0 if no camera is bound or the device reports no step. */
    fun exposureCompensationStep(): Double {
        val step = camera?.cameraInfo?.exposureState?.exposureCompensationStep ?: return 0.0
        return if (step.denominator == 0) 0.0 else step.numerator.toDouble() / step.denominator.toDouble()
    }

    private fun meteringPointFactory(): MeteringPointFactory? {
        val boundPreview = preview ?: return null
        val resolutionInfo = boundPreview.resolutionInfo ?: return null
        return SurfaceOrientedMeteringPointFactory(
            resolutionInfo.resolution.width.toFloat(),
            resolutionInfo.resolution.height.toFloat(),
        )
    }

    private fun selectorFor(lensDirection: LensDirection): CameraSelector =
        when (lensDirection) {
            LensDirection.FRONT -> CameraSelector.DEFAULT_FRONT_CAMERA
            LensDirection.BACK -> CameraSelector.DEFAULT_BACK_CAMERA
        }

    private suspend fun getOrCreateProvider(): ProcessCameraProvider {
        cameraProvider?.let { return it }
        return ProcessCameraProvider.getInstance(context).await()
    }

}

