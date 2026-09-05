package com.d3.d3_camera

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers this plugin and implements [CameraHostApi] -- the Kotlin side
 * of the Phase 1 Pigeon contract. Delegates all actual CameraX work to
 * [CameraXSession]/[CameraCapabilityReader]; this class's own job is
 * wiring the generated API to those collaborators and translating
 * failures into [FlutterError]s with stable codes the Dart side maps onto
 * its typed exception hierarchy.
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

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        session = CameraXSession(binding.applicationContext)
        flutterApi = CameraFlutterApi(binding.binaryMessenger)
        CameraHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        session?.unbind()
        session = null
        flutterApi = null
        CameraHostApi.setUp(binding.binaryMessenger, null)
    }

    override suspend fun initialize(initialLensDirection: LensDirection): CameraCapabilityData {
        val activeSession =
            session
                ?: throw FlutterError(
                    "camera_unavailable",
                    "Plugin is not attached to a Flutter engine.",
                    null,
                )

        try {
            val cameraInfo = activeSession.bind(initialLensDirection)
            return CameraCapabilityReader.read(
                cameraInfo,
                activeSession.availableLensDirections(),
            )
        } catch (e: IllegalArgumentException) {
            // CameraX's own signal that no camera matches the requested
            // selector.
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

    override suspend fun dispose() {
        session?.unbind()
    }
}
