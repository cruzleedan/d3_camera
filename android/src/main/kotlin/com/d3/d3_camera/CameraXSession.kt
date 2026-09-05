package com.d3.d3_camera

import android.content.Context
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.guava.await

/**
 * Owns a single CameraX session: binding, unbinding, and reporting which
 * lens directions are actually available on this device.
 *
 * Bound to [ProcessLifecycleOwner] -- the whole application's foreground/
 * background lifecycle -- rather than a Flutter [android.app.Activity].
 * This is a deliberate Phase 1 design choice: an Activity-bound session
 * would tie this plugin to `ActivityAware` and break the moment a
 * consuming app hosts the camera in something other than a single-
 * Activity Flutter setup (e.g. a native Android screen embedding a
 * Flutter fragment). [ProcessLifecycleOwner] already tracks app-level
 * foreground/background transitions, which is the granularity Phase 1's
 * pause/resume semantics need -- CameraX itself unbinds/rebinds preview
 * on lifecycle STOP/START, so backgrounding the app releases the camera
 * without this class polling for it.
 *
 * No preview or capture use case is bound yet -- Phase 1 only proves the
 * provider can be acquired and torn down cleanly, plus capability
 * reporting via [CameraCapabilityReader]. [Preview]/`ImageCapture` are
 * added when Phase 2 needs them.
 */
class CameraXSession(private val context: Context) {
    private var cameraProvider: ProcessCameraProvider? = null
    private val lifecycleOwner: LifecycleOwner = ProcessLifecycleOwner.get()

    /**
     * Acquires the [ProcessCameraProvider] and binds an empty use-case
     * group for [lensDirection] to prove the session can be bound at all
     * -- CameraX throws if the requested lens has no matching camera
     * before any use case is even added. Returns the bound
     * [androidx.camera.core.CameraInfo] so the caller (the Pigeon host
     * API handler) can read capability from it.
     *
     * Throws [IllegalArgumentException] (surfaced by CameraX itself) if
     * no camera matches [lensDirection].
     */
    suspend fun bind(lensDirection: LensDirection): androidx.camera.core.CameraInfo {
        val provider = getOrCreateProvider()
        cameraProvider = provider

        val selector =
            when (lensDirection) {
                LensDirection.FRONT -> CameraSelector.DEFAULT_FRONT_CAMERA
                LensDirection.BACK -> CameraSelector.DEFAULT_BACK_CAMERA
            }

        provider.unbindAll()
        // No use cases bound yet (Phase 1 has no preview/capture) --
        // bindToLifecycle requires at least awareness of the selector to
        // validate camera availability, achieved here by binding a
        // Preview use case with no active surface consumer. This is
        // replaced by a real Preview/ImageCapture binding in Phase 2;
        // it is not a placeholder left permanently.
        val preview = Preview.Builder().build()
        val camera = provider.bindToLifecycle(lifecycleOwner, selector, preview)
        return camera.cameraInfo
    }

    /** Unbinds all use cases. Safe to call even if never bound. */
    fun unbind() {
        cameraProvider?.unbindAll()
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

    private suspend fun getOrCreateProvider(): ProcessCameraProvider {
        cameraProvider?.let { return it }
        return ProcessCameraProvider.getInstance(context).await()
    }
}
