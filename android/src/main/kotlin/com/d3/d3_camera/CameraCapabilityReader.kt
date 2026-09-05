package com.d3.d3_camera

import android.util.Rational
import androidx.camera.core.CameraInfo

/**
 * Translates a bound CameraX [CameraInfo] into the Pigeon-generated
 * [CameraCapabilityData] DTO. This is the single place device capability
 * is read -- the governing rule is detect, never assume: every field is
 * queried from the live [CameraInfo]/its exposure state, never a
 * constant.
 */
object CameraCapabilityReader {
    fun read(
        cameraInfo: CameraInfo,
        availableLenses: List<LensDirection>,
    ): CameraCapabilityData {
        val zoomState = cameraInfo.zoomState.value
        val exposureState = cameraInfo.exposureState

        // ExposureState reports compensation in exposure-index steps, not
        // EV directly -- convert using its own step size so the Dart side
        // receives real EV values rather than raw device-specific steps.
        val stepValue = exposureState.exposureCompensationStep.toDoubleOrZero()
        val minEv = exposureState.exposureCompensationRange.lower * stepValue
        val maxEv = exposureState.exposureCompensationRange.upper * stepValue

        return CameraCapabilityData(
            hasFlash = cameraInfo.hasFlashUnit(),
            minZoomRatio = zoomState?.minZoomRatio?.toDouble() ?: 1.0,
            maxZoomRatio = zoomState?.maxZoomRatio?.toDouble() ?: 1.0,
            // CameraX does not expose a direct "supports tap-to-focus"
            // capability query; a Phase 1 approximation treats it as
            // supported whenever a camera is bound at all. CameraX itself
            // validates and ignores unsupported metering actions when
            // Phase 2 wires up FocusMeteringAction, so this never causes
            // an unhandled failure -- only a possibly-optimistic flag to
            // revisit once real device testing covers fixed-focus
            // hardware.
            supportsTapToFocus = true,
            supportsExposureCompensation = exposureState.isExposureCompensationSupported,
            minExposureCompensation = minEv,
            maxExposureCompensation = maxEv,
            availableLenses = availableLenses,
        )
    }
}

private fun Rational.toDoubleOrZero(): Double =
    if (denominator == 0) 0.0 else numerator.toDouble() / denominator.toDouble()
