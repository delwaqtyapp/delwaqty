import 'package:flutter/material.dart';

/// Lays out tile widgets in rows of [columnsFor] and stretches the tiles of
/// a short last row evenly across the full width, so an odd item never
/// dangles as a small orphan under a full row (owner feedback: at large
/// system font sizes the three profile tiles wrapped 2-on-top + 1-below and
/// read as broken).
///
/// Column count adapts to both available width and text scale: large text
/// needs wider tiles, so fewer columns fit.
class AdaptiveTileWrap extends StatelessWidget {
  const AdaptiveTileWrap({
    super.key,
    required this.children,
    this.gap = 10,
    this.minTileWidth = 100,
    this.maxColumns = 3,
  });

  final List<Widget> children;
  final double gap;

  /// Tiles narrower than this become unreadable; drop a column instead.
  final double minTileWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        // Large text needs wider tiles: scale the minimum tile width with
        // the text scale (clamped so extreme scales stay sane).
        final effectiveMin =
            minTileWidth * textScale.clamp(1.0, 1.6).toDouble();
        var columns = maxColumns;
        while (columns > 1 &&
            (constraints.maxWidth - gap * (columns - 1)) / columns <
                effectiveMin) {
          columns--;
        }

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final rowChildren = children.sublist(
            i,
            i + columns > children.length ? children.length : i + columns,
          );
          final tileWidth =
              (constraints.maxWidth - gap * (rowChildren.length - 1)) /
              rowChildren.length;
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < rowChildren.length; j++) ...[
                  if (j > 0) SizedBox(width: gap),
                  SizedBox(width: tileWidth, child: rowChildren[j]),
                ],
              ],
            ),
          );
          if (i + columns < children.length) {
            rows.add(SizedBox(height: gap));
          }
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
