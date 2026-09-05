import 'package:flutter/material.dart';

import '../camera/aspect_ratio_preset.dart';
import '../camera/flash_mode.dart';

/// A circular icon button styled for overlay on a camera feed.
///
/// Exported so a consumer building custom controls can match the
/// built-in chrome without re-deriving its styling, rather than having
/// to choose between the whole prebuilt screen and starting from zero.
class D3CameraControlButton extends StatelessWidget {
  const D3CameraControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.white,
      disabledColor: Colors.white24,
      style: IconButton.styleFrom(backgroundColor: Colors.black45),
    );
  }
}

/// The large circular capture button.
class D3ShutterButton extends StatelessWidget {
  const D3ShutterButton({super.key, required this.onPressed, this.size = 72});

  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onPressed == null ? Colors.white24 : Colors.white,
          border: Border.all(color: Colors.white70, width: 3),
        ),
      ),
    );
  }
}

/// Cycles flash off -> on -> auto, showing the current mode's icon.
class D3FlashButton extends StatelessWidget {
  const D3FlashButton({
    super.key,
    required this.flashMode,
    required this.onPressed,
  });

  final FlashMode flashMode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return D3CameraControlButton(
      icon: switch (flashMode) {
        FlashMode.off => Icons.flash_off,
        FlashMode.on => Icons.flash_on,
        FlashMode.auto => Icons.flash_auto,
      },
      onPressed: onPressed,
    );
  }
}

/// Toggles between 4:3 and 16:9 -- the two presets native camera apps
/// (Pixel Camera, iOS Camera) expose, both defaulting to 4:3. A text
/// label rather than an icon, since "4:3"/"16:9" isn't well represented
/// by a single glyph the way flash/switch are.
class D3AspectRatioButton extends StatelessWidget {
  const D3AspectRatioButton({
    super.key,
    required this.aspectRatio,
    required this.onPressed,
  });

  final AspectRatioPreset aspectRatio;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (aspectRatio) {
      AspectRatioPreset.ratio4x3 => '4:3',
      AspectRatioPreset.ratio16x9 => '16:9',
    };
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white24,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(12),
        minimumSize: const Size(48, 48),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
