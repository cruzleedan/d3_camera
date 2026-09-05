# d3_camera

A customizable Flutter camera + image annotation package. Live preview,
still capture, flash/zoom/focus/exposure control, and on-image annotation
(shapes, arrows, freehand, text) as reusable Dart primitives — no
predefined camera screen. CameraX-backed on Android; the Dart API is
structured so an iOS implementation can be added later without changes to
consuming code.

**Status:** early scaffold. No functional camera or annotation code yet —
see [Development phases](#development-phases) below.

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
3. Annotation system — model, controller, overlay widget, undo/redo
4. Image transformation / export — coordinate transforms, export pipeline,
   crop
5. Performance optimization
6. Testing / device compatibility

## Getting started (once functional)

```dart
final cameraController = CustomCameraController(
  configuration: const CameraConfiguration(),
);
await cameraController.initialize();

CustomCameraPreview(controller: cameraController);
```

See `example/` for a fuller build-your-own-UI walkthrough as the package
matures.
