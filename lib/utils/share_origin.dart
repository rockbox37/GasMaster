import 'package:flutter/material.dart';

/// Anchor rect for [Share] on iOS.
///
/// `share_plus` requires a non-empty [sharePositionOrigin] on iPad and may
/// fail or skip the sheet when it is missing/invalid on iPhone as well.
/// Prefer the triggering widget's [BuildContext]; fall back to a 1×1 point at
/// the screen center when the render box is unavailable or out of bounds.
Rect sharePositionOriginFor(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final fallback = Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );

  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return fallback;

  final rect = box.localToGlobal(Offset.zero) & box.size;
  if (rect.width <= 0 ||
      rect.height <= 0 ||
      rect.left < 0 ||
      rect.top < 0 ||
      rect.right > size.width ||
      rect.bottom > size.height) {
    return fallback;
  }
  return rect;
}
