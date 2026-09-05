import 'package:flutter/material.dart';

import '../camera/camera_controller.dart';

/// A row of discrete zoom-level pills (1x, 2x, ...) rather than a bare
/// full-width Slider -- closer to how real camera apps present zoom, and
/// more usable via touch than dragging a thin slider thumb (a bare
/// Slider was the first implementation and was rejected in on-device
/// testing as awkward to hit). Levels are generated from the device's
/// own reported zoom range rather than hardcoded, since that range
/// varies per device and lens.
class D3ZoomLevelBar extends StatelessWidget {
  const D3ZoomLevelBar({super.key, required this.controller});

  final CustomCameraController controller;

  List<double> _levels(double min, double max) {
    return <double>{
      min,
      1.0,
      2.0,
      3.0,
      5.0,
      max,
    }.where((level) => level >= min && level <= max).toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final capability = controller.value.capability;
    if (capability == null) return const SizedBox.shrink();

    final levels = _levels(capability.minZoomRatio, capability.maxZoomRatio);
    final current = controller.value.zoomRatio;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final level in levels)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ZoomPill(
                label: level == level.roundToDouble()
                    ? '${level.toInt()}x'
                    : '${level.toStringAsFixed(1)}x',
                selected: (current - level).abs() < 0.05,
                onTap: () => controller.setZoom(level),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoomPill extends StatelessWidget {
  const _ZoomPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
