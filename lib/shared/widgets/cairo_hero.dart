import 'package:flutter/material.dart';

import 'package:delwaqty/shared/widgets/cairo_hero_painter.dart';

/// Backdrop of the profile hero: a Cairo panorama (dusk image in dark mode,
/// daylight image in light mode) that sits on a sky-coloured fill and fades
/// into the page background at the bottom, so the hero and the content read as
/// one surface. The painted [CairoHeroPainter] scene is the fallback while the
/// image loads or if it fails.
///
/// Place it as the first child of a `Stack(clipBehavior: Clip.none)` that is
/// the hero: the panorama extends [overlap] below the hero box, so the content
/// that follows can overlap the faded edge.
class CairoHeroBackdrop extends StatelessWidget {
  const CairoHeroBackdrop({super.key, this.overlap = 0});

  final double overlap;

  static const double _aspect = 1200 / 500;

  /// Text colour that reads on the hero in the current brightness.
  static Color ink(Brightness b) =>
      b == Brightness.dark ? Colors.white : const Color(0xFF2A1A4D);

  static List<Shadow> inkShadows(Brightness b) => b == Brightness.dark
      ? const [
          Shadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 1)),
        ]
      : const [Shadow(color: Color(0x99FFFFFF), blurRadius: 6)];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final sky = dark ? const Color(0xFF3C2D6D) : const Color(0xFF5EACBB);
    final scrim = dark ? const Color(0x59000000) : const Color(0x73FFFFFF);
    final asset = dark
        ? 'assets/profile/hero_dusk.webp'
        : 'assets/profile/hero_daylight.webp';

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: ColoredBox(color: sky)),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: -overlap,
            child: LayoutBuilder(
              builder: (context, c) {
                final h = c.maxWidth / _aspect;
                Widget fallback() => SizedBox(
                  height: h,
                  child: CustomPaint(painter: CairoHeroPainter(dark: dark)),
                );
                return SizedBox(
                  height: h,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        asset,
                        fit: BoxFit.fill,
                        cacheWidth: 1200,
                        gaplessPlayback: true,
                        frameBuilder: (_, child, frame, sync) =>
                            (frame == null && !sync) ? fallback() : child,
                        errorBuilder: (_, _, _) => fallback(),
                      ),
                      // Top of the panorama blends into the sky fill.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [sky, sky.withValues(alpha: 0)],
                            stops: const [0, 0.32],
                          ),
                        ),
                      ),
                      // Bottom of the panorama fades into the page background.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [bg.withValues(alpha: 0), bg],
                            stops: const [0.35, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Soft scrim behind the name and chip for text contrast.
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 8,
            height: 150,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scrim.withValues(alpha: 0),
                    scrim,
                    scrim.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
