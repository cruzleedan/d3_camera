import 'dart:io';

import 'package:flutter/material.dart';

import '../camera/capture_result.dart';

/// Full-screen post-capture review: shows what was just captured until
/// the user accepts or discards it. A capture with a shutter sound but
/// no visible result reads as broken, so this is part of the default
/// flow rather than an optional extra.
///
/// Both callbacks are optional. When [onAccept] is null only a dismiss
/// affordance is shown, which is the right shape for a "review and go
/// back" flow; supply it for a "use this photo" flow.
class D3CaptureReviewScreen extends StatelessWidget {
  const D3CaptureReviewScreen({
    super.key,
    required this.capture,
    required this.onDismiss,
    this.onAccept,
    this.showMetadata = false,
  });

  final ImageCaptureResult capture;
  final VoidCallback onDismiss;
  final VoidCallback? onAccept;

  /// Shows the capture's pixel dimensions and lens. Off by default --
  /// it's a debugging aid, not something an end user needs.
  final bool showMetadata;

  @override
  Widget build(BuildContext context) {
    // This screen may be shown by swapping state rather than pushing a
    // route, in which case nothing sits on the navigator stack for
    // Android's back gesture to pop -- without claiming the intent here,
    // back closes the whole app instead of dismissing the review.
    // Routing it to onDismiss keeps gesture and button in agreement.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDismiss();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Center(
                // A SizedBox at the image's true pixel size, scaled by
                // FittedBox to fill whichever axis runs out first.
                //
                // The earlier AspectRatio was sized by the available
                // *height* alone, so a portrait photo in a landscape
                // window rendered as a narrow column with the horizontal
                // space unused -- the photo got smaller when the screen
                // got wider. FittedBox scales instead of constraining.
                //
                // Keeping a single box around image and overlay is the
                // load-bearing part: it is what stops the two disagreeing
                // about where content sits. Sizing it to the image's own
                // pixels makes that agreement structural rather than a
                // matching pair of aspect-ratio calculations.
                child: FittedBox(
                  child: SizedBox(
                    width: capture.width.toDouble(),
                    height: capture.height.toDouble(),
                    child: Image.file(
                      File(capture.filePath),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            // Column, not a bare Row: this sits in a StackFit.expand
            // Stack, so a Row stretches to the full screen height and
            // its default centered cross-axis alignment parks its
            // children halfway down, floating over the middle of the
            // photo. Pinning chrome to the top and bottom edges keeps
            // each anchored in the letterbox, the way a native review
            // screen reads.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    D3CameraControlButtonRow(
                      onDismiss: onDismiss,
                      onAccept: onAccept,
                    ),
                    const Spacer(),
                    if (showMetadata)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${capture.width}x${capture.height} '
                            '(${capture.capturedLensDirection.name})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top row of the review screen: dismiss on the left, accept (when
/// offered) on the right.
class D3CameraControlButtonRow extends StatelessWidget {
  const D3CameraControlButtonRow({
    super.key,
    required this.onDismiss,
    this.onAccept,
  });

  final VoidCallback onDismiss;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onDismiss,
          icon: const Icon(Icons.close),
          color: Colors.white,
          style: IconButton.styleFrom(backgroundColor: Colors.black45),
        ),
        if (onAccept != null)
          IconButton(
            onPressed: onAccept,
            icon: const Icon(Icons.check),
            color: Colors.white,
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
          ),
      ],
    );
  }
}
