# d3_camera

A customizable Flutter camera package. Live preview, still capture, and
flash/zoom/focus/exposure control, offered as a turnkey screen, a
lifecycle helper, or bare primitives — use whichever layer fits.
CameraX-backed on Android; the Dart API is structured so an iOS
implementation can be added later without changes to consuming code.

**Annotation lives in [d3_image_annotator](https://github.com/cruzleedan/d3_image_annotator).**
It started here but was split out: annotating an image has nothing to do
with cameras, and it is wanted for photos that already exist. Compose the
two to capture-then-annotate — this package has no dependency on it.

**Status:** camera functionality complete (phases 1–2), verified on a
physical device. See [Development phases](#development-phases) below.

## Why this exists

Built for apps that need a fully custom camera UI (their own shutter
button, controls, and overlays) plus the ability to mark up captured
photos — without adopting a fixed camera screen or a general-purpose photo
editor. First consumer: [Site Inspector](https://github.com/cruzleedan/site_inspector)'s
field-inspection defect photos.

Explicitly **not** in scope: ML object detection, OCR, barcode/QR scanning,
or any computer-vision inference.

## Architecture

The full technical design (requirements, layering, coordinate-system
design, platform boundary, API surface, and phased plan) was written up
before any implementation began. It lives outside this repo, alongside the
rest of this codebase's private planning docs. In short:

- **Dart owns almost everything** — the camera state machine, the entire
  annotation system (model, hit-testing, rendering, undo/redo,
  serialization), and the image export pipeline (decode/crop/composite/
  encode, run in an isolate).
- **Kotlin owns only** binding to CameraX, feeding preview frames to a
  Flutter `Texture`, and reporting device capability (zoom range, flash
  availability, AF/AE support).
- **Coordinates are normalized `[0,1]` image space** — the only persisted
  form for annotation geometry, so preview and exported-image geometry can
  never drift apart.

## Development phases

1. Camera foundation — Pigeon contract, CameraX session, controller state
   machine
2. Preview and controls — Texture preview, capture, flash/zoom/focus/
   exposure, capability detection
3. ~~Annotation system~~ — moved to
   [d3_image_annotator](https://github.com/cruzleedan/d3_image_annotator)
4. Performance optimization
5. Testing / device compatibility

## Getting started

The package offers three layers. Each is built from the one beneath it,
so starting at the top costs nothing in flexibility later — when you
outgrow a layer, drop to the next rather than fighting its options.

### 1. Turnkey — a working camera in one call

```dart
final capture = await D3CameraScreen.show(
  context,
  requestPermission: () async =>
      (await Permission.camera.request()).isGranted,
);
```

Live preview, shutter, pinch- and tap-to-zoom, flash, 4:3/16:9 toggle,
camera switch, tap-to-focus, a close button, and a post-capture review
screen. Individual controls can be switched off (`showFlashToggle:
false`, …).

When the screen is embedded rather than pushed, give it an `onClose` so
its close button does something meaningful in your own flow:

```dart
D3CameraScreen(
  onClose: () => Navigator.of(context).pop(),
  onCaptured: (capture) { /* … */ },
)
```

### 2. Lifecycle handled, UI yours

`D3CameraScope` owns the controller's lifecycle — permission,
initialize, listen, dispose — and hands you a ready controller:

```dart
D3CameraScope(
  requestPermission: myPermissionRequest,
  builder: (context, controller) => Stack(
    children: [
      CustomCameraPreview(controller: controller),
      MyOwnControls(controller: controller),
    ],
  ),
)
```

Individual control widgets (`D3ShutterButton`, `D3ZoomLevelBar`,
`D3FlashButton`, `D3AspectRatioButton`) are exported, so you can mix
built-in chrome with your own.

### 3. Full control

```dart
final controller = CustomCameraController(
  configuration: const CameraConfiguration(),
);
await controller.initialize();

CustomCameraPreview(controller: controller);
```

**Sizing the preview:** use `state.displayPreviewSize`, not
`previewSize`. The latter is the sensor-space resolution, which is
landscape on a portrait-held phone — sizing a box from it frames the feed
sideways relative to the captured image.

**Permissions:** this package takes no permissions-plugin dependency —
which one to use is your app's choice — so every entry point accepts a
callback instead.

See `example/` for all three layers running side by side.
