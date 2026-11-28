import 'package:flutter/material.dart';

import 'package:delwaqty/shared/widgets/cairo_hero_painter.dart';

/// Backdrop of the customer home hero: the Cairo panorama (dusk in dark mode,
/// daylight in light mode) sits at the bottom of the hero on a sky fill taken
/// from the image's top row, so there is no seam above it, and it fades into
/// the page background at the bottom so the hero and the content that follows
/// read as one surface. [CairoHeroPainter] is the fallback while the image
/// loads or if it fails.
///
/// Use as the first child of the hero `Stack`.
class HomeHeroBackdrop extends StatelessWidget {
  const HomeHeroBackdrop({super.key});

  static const double _aspect = 1200 / 800;

  /// Top-row colours of the two images.
  static const Color duskSky = Color(0xFF302B8A);
  static const Color daylightSky = Color(0xFF50C3EC);

  /// Text and icon colour that reads on the hero in this brightness.
  static Color ink(Brightness b) =>
      b == Brightness.dark ? Colors.white : const Color(0xFF1F1442);

  /// Frosted fill for chips and the search bar over the hero.
  static Color glass(Brightness b) =>
      b == Brightness.dark ? const Color(0x14FFFFFF) : const Color(0xB3FFFFFF);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final sky = dark ? duskSky : daylightSky;
    final asset = dark
        ? 'assets/egypt/home_hero_dusk.webp'
        : 'assets/egypt/home_hero_daylight.webp';

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: sky),
          Align(
            alignment: Alignment.bottomCenter,
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
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [sky, sky.withValues(alpha: 0)],
                            stops: const [0, 0.18],
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [bg.withValues(alpha: 0), bg],
                            stops: const [0.55, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
