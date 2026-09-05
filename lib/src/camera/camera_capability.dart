import 'package:meta/meta.dart';

/// Which physical camera a session can be bound to.
enum CameraLensDirection { front, back }

/// Device-reported limits, detected once at initialization time and never
/// assumed. Flash availability, zoom range, and AF/AE support vary widely
/// across Android hardware — every field here reflects what the active
/// device actually reported, not a hardcoded default.
///
/// Consumers use this to decide what controls to show at all (e.g. hide
/// a flash toggle entirely on a device with no flash unit) rather than
/// showing a control that silently no-ops.
@immutable
class CameraCapability {
  const CameraCapability({
    required this.hasFlash,
    required this.minZoomRatio,
    required this.maxZoomRatio,
    required this.supportsTapToFocus,
    required this.supportsExposureCompensation,
    required this.minExposureCompensation,
    required this.maxExposureCompensation,
    required this.availableLenses,
  });

  final bool hasFlash;
  final double minZoomRatio;
  final double maxZoomRatio;
  final bool supportsTapToFocus;
  final bool supportsExposureCompensation;
  final double minExposureCompensation;
  final double maxExposureCompensation;
  final List<CameraLensDirection> availableLenses;

  /// Clamps [value] to [minZoomRatio, maxZoomRatio]. Zoom is a continuous
  /// control where clamping — not throwing — matches user expectation: a
  /// zoom slider dragged past a device's max should just stop there.
  double clampZoom(double value) => value.clamp(minZoomRatio, maxZoomRatio);

  /// Clamps [value] to [minExposureCompensation, maxExposureCompensation].
  double clampExposureCompensation(double value) =>
      value.clamp(minExposureCompensation, maxExposureCompensation);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraCapability &&
          runtimeType == other.runtimeType &&
          hasFlash == other.hasFlash &&
          minZoomRatio == other.minZoomRatio &&
          maxZoomRatio == other.maxZoomRatio &&
          supportsTapToFocus == other.supportsTapToFocus &&
          supportsExposureCompensation == other.supportsExposureCompensation &&
          minExposureCompensation == other.minExposureCompensation &&
          maxExposureCompensation == other.maxExposureCompensation &&
          _listEquals(availableLenses, other.availableLenses);

  @override
  int get hashCode => Object.hash(
    hasFlash,
    minZoomRatio,
    maxZoomRatio,
    supportsTapToFocus,
    supportsExposureCompensation,
    minExposureCompensation,
    maxExposureCompensation,
    Object.hashAll(availableLenses),
  );

  @override
  String toString() =>
      'CameraCapability(hasFlash: $hasFlash, zoom: '
      '$minZoomRatio–$maxZoomRatio, tapToFocus: $supportsTapToFocus, '
      'exposureCompensation: $supportsExposureCompensation '
      '($minExposureCompensation–$maxExposureCompensation), '
      'availableLenses: $availableLenses)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
