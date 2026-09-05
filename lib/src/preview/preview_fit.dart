/// How `CustomCameraPreview` lays its Texture content out against the
/// widget's allocated bounds when the two aspect ratios differ (the
/// common case -- the Texture's content aspect ratio is fixed by the
/// bound sensor/Preview resolution, not the widget's size).
enum PreviewFit {
  /// Scales up and center-crops so the preview fills the widget's full
  /// bounds with no letterboxing. The default -- matches a full-bleed
  /// `Stack(fit: StackFit.expand)` composition. Trade-off: the edges of
  /// the sensor's field of view are not visible on screen.
  cover,

  /// Scales to fit entirely within the widget's bounds, letterboxed on
  /// the long axis. Guarantees what's on screen exactly matches what
  /// will be captured -- no cropped-off content -- which matters once
  /// annotation coordinate-mapping is in play (a later phase).
  contain,
}
