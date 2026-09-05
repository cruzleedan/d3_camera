/// Preview/capture aspect ratio, matching the presets native camera apps
/// expose (Pixel Camera and iOS Camera both default to 4:3 with a 16:9
/// toggle). Applied identically to the live preview and still capture --
/// see `CustomCameraController.setAspectRatio`'s own docs for why both
/// must always share one ratio.
///
/// Ratio names follow standard camera convention: 4:3 and 16:9 describe
/// the sensor's native landscape width:height: in portrait, the on-
/// screen box is taller than it is wide (i.e. displayed as
/// height:width -- a 4:3 photo held in portrait is 3 units wide by 4
/// units tall, not the other way around).
enum AspectRatioPreset { ratio4x3, ratio16x9 }
