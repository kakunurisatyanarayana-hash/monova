import 'package:flutter/material.dart';

import 'theme.dart';

/// The atmospheric background behind every page: a deep base with two soft, drifting light sources.
/// It sits behind the whole app, so cards and bars can be frosted glass that lets the light show through.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.colors});

  final MonovaColors colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.base),
        Positioned(
          top: -180,
          left: -140,
          child: _Glow(color: colors.glowA, size: 620),
        ),
        Positioned(
          bottom: -220,
          right: -160,
          child: _Glow(color: colors.glowB, size: 680),
        ),
        Positioned(
          top: 280,
          right: -60,
          child: _Glow(color: colors.glowA.withValues(alpha: 0.5), size: 340),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
