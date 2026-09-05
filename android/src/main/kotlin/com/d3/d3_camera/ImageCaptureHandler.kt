package com.d3.d3_camera

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import java.io.File
import java.io.FileOutputStream
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Wraps [ImageCapture.takePicture] as a suspend call and normalizes the
 * resulting file so its pixels are actually upright, not merely EXIF-
 * tagged as needing rotation.
 *
 * The rotation applied here is [computeRotationDegrees] -- the same
 * formula (and, for the back camera on the one device this has been
 * verified against, the same numeric value) used to correct the live
 * preview in Dart. CameraX's own `ImageCapture`-written EXIF tag is
 * deliberately not used: it was found to disagree with the value
 * confirmed correct for the live preview on a real device (see
 * [computeRotationDegrees]'s own docs), and trusting a value already
 * known to be wrong in one case is worse than computing it the same way
 * everywhere.
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
        sensorOrientationDegrees: Int,
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

        val sign = if (lensDirection == LensDirection.FRONT) 1 else -1
        val degrees =
            computeRotationDegrees(
                sensorOrientationDegrees = sensorOrientationDegrees,
                deviceOrientationDegrees = 0,
                sign = sign,
            )
        if (degrees != 0) {
            rotatePixelsAndResetExif(outputFile, degrees)
        }

        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(outputFile.absolutePath, options)

        return Result(
            filePath = outputFile.absolutePath,
            width = options.outWidth,
            height = options.outHeight,
            exifOrientationDegrees = 0,
            capturedLensDirection = lensDirection,
        )
    }

    /**
     * Decodes [file], rotates its pixels by [degrees] clockwise, and
     * re-encodes over the same path with EXIF orientation reset to
     * normal. A full decode-rotate-encode pass is memory-heavier than
     * only ever fixing up EXIF metadata, but is correct everywhere the
     * file is later opened -- an acceptable and deliberate trade-off for
     * still photos at this stage (Phase 2's scope is correctness, not
     * yet large-image memory optimization; see the design doc's own
     * export-pipeline phase for where a stream-based approach belongs
     * once this needs to scale beyond a single still capture at a time).
     */
    private fun rotatePixelsAndResetExif(file: File, degrees: Int) {
        val original =
            BitmapFactory.decodeFile(file.absolutePath)
                ?: return
        val matrix = Matrix().apply { postRotate(degrees.toFloat()) }
        val rotated =
            Bitmap.createBitmap(original, 0, 0, original.width, original.height, matrix, true)

        FileOutputStream(file).use { out ->
            rotated.compress(Bitmap.CompressFormat.JPEG, 95, out)
        }

        if (rotated !== original) {
            original.recycle()
        }
        rotated.recycle()

        val exif = ExifInterface(file.absolutePath)
        exif.setAttribute(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL.toString(),
        )
        exif.saveAttributes()
    }
}
