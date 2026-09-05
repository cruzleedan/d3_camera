package com.d3.d3_camera

import android.media.ExifInterface
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Wraps [ImageCapture.takePicture] as a suspend call and reads back the
 * resulting file's actual dimensions and EXIF orientation. No decoding,
 * cropping, or bitmap manipulation happens here -- that is Dart's job
 * (see the export pipeline planned for a later phase). This is strictly
 * "call CameraX, write a file, report what's in it."
 */
object ImageCaptureHandler {
    data class Result(
        val filePath: String,
        val width: Int,
        val height: Int,
        val exifOrientationDegrees: Int,
        val capturedLensDirection: LensDirection,
    )

    suspend fun capture(
        imageCapture: ImageCapture,
        cacheDir: File,
        lensDirection: LensDirection,
    ): Result {
        val outputDir = File(cacheDir, "d3_camera").apply { mkdirs() }
        val outputFile = File(outputDir, "capture_${System.currentTimeMillis()}.jpg")
        val outputOptions = ImageCapture.OutputFileOptions.Builder(outputFile).build()

        suspendCancellableCoroutine<Unit> { continuation ->
            imageCapture.takePicture(
                outputOptions,
                directExecutor(),
                object : ImageCapture.OnImageSavedCallback {
                    override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                        continuation.resume(Unit)
                    }

                    override fun onError(exception: ImageCaptureException) {
                        continuation.resumeWithException(exception)
                    }
                },
            )
        }

        val exif = ExifInterface(outputFile.absolutePath)
        val orientationTag =
            exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        val degrees =
            when (orientationTag) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }

        val options = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
        android.graphics.BitmapFactory.decodeFile(outputFile.absolutePath, options)

        return Result(
            filePath = outputFile.absolutePath,
            width = options.outWidth,
            height = options.outHeight,
            exifOrientationDegrees = degrees,
            capturedLensDirection = lensDirection,
        )
    }
}
