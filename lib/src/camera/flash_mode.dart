/// Flash behavior for still capture. `on` and `auto` are only meaningful
/// on a lens with a flash unit -- see `CameraCapability.hasFlash`; the
/// controller does not hide this enum's other values on a flashless
/// device, but the native side will reject them (surfaced as a typed
/// exception) if actually applied.
enum FlashMode { off, on, auto }
