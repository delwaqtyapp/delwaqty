import 'package:flutter/material.dart';

/// Shared desktop layout primitives (UI review batch 8): pages read as
/// stretched mobile layouts at desktop widths. Wrap page content in
/// [ResponsiveContent] to center it inside a max-width container, and use
/// [ResponsiveGrid.columns] for responsive grid column counts.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) {
      return Padding(padding: padding, child: child);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// Responsive column counts for product/merchant grids.
class ResponsiveGrid {
  ResponsiveGrid._();

  static int columns(BuildContext context, {int mobile = 2}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1400) return 5;
    if (w >= 1100) return 4;
    if (w >= 900) return 3;
    return mobile;
  }
}
