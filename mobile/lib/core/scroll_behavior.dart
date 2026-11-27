import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets mouse and trackpad drag scroll lists on desktop browsers, not just touch.
/// Flutter's default leaves mouse dragging off, which makes horizontal lists unreachable with a mouse.
class MonovaScrollBehavior extends MaterialScrollBehavior {
  const MonovaScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
