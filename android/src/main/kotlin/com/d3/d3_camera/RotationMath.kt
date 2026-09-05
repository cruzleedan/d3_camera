package com.d3.d3_camera

/**
 * Clockwise degrees needed to correct a camera frame's rotation, given
 * the sensor's physical mounting angle and the current device
 * orientation. The single source of truth for rotation correction across
 * this plugin -- both the live preview (mirrored in Dart as
 * `computeRotationQuarterTurns` in `preview_transform.dart`, converted to
 * quarter turns for a `RotatedBox`) and still capture (used directly here
 * in [ImageCaptureHandler] to physically rotate the saved JPEG's pixels)
 * apply this exact formula, so a photo review always matches what was
 * framed live.
 *
 * CameraX's own `ImageCapture`-written EXIF orientation tag was tried
 * first and found to disagree with this formula on a real device (EXIF
 * reported 180 degrees where 90 degrees was the value confirmed correct
 * for the live preview via on-device testing) -- the two are computed by
 * different, unreconciled paths inside CameraX itself. Rather than trust
 * a value found to be wrong in practice, this package computes its own
 * correction from the same sensor-orientation data throughout.
 *
 * [sign] is `-1` for the back camera and `1` for the front camera -- the
 * front sensor is mounted mirrored relative to the back, which flips the
 * sign of the correction needed.
 */
fun computeRotationDegrees(
    sensorOrientationDegrees: Int,
    deviceOrientationDegrees: Int,
    sign: Int,
): Int {
    return ((sensorOrientationDegrees - deviceOrientationDegrees * sign) % 360 + 360) % 360
}
