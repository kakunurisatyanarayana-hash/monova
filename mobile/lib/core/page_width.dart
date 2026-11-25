import 'package:flutter/material.dart';

/// Limits a page's content to [maxWidth] and centres it, so forms and calculators stay readable on wide screens.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
