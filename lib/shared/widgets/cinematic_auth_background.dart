import 'package:flutter/material.dart';

/// Cinematic warm Egyptian-futurism backdrop for the auth flow (login /
/// register / onboarding).
///
/// Uses the bundled intro art (warm Cairo/Nile scene, ADR-076) with warm dark
/// gradient scrims + faint golden/purple atmospheric tint + minimal vignette.
/// Static gradients only — no per-frame blur (ADR-044 memory contract).
class CinematicAuthBackground extends StatefulWidget {
  const CinematicAuthBackground({super.key, this.child});

  final Widget? child;

  @override
  State<CinematicAuthBackground> createState() =>
      _CinematicAuthBackgroundState();
}

class _CinematicAuthBackgroundState extends State<CinematicAuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF160D0D)),
        FadeTransition(
          opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          child: Transform.scale(
            scale: 1.05,
            child: Image.asset(
              'assets/egypt/intro_egypt_cinematic_background.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.0, -0.05),
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF160D0D), Color(0xFF3A1E10), Color(0xFF160D0D)],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Cinematic warm gradient — keeps the image visible, the text area quiet.
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF140A08),
                Color(0xFF140A08),
                Color(0xFF140A08),
                Color(0xFF140A08),
                Color(0xFF0A0614),
              ],
              stops: [0.0, 0.2, 0.5, 0.78, 1.0],
            ),
          ),
        ),
        // Warm golden glow behind the logo area + faint brand tint at the base.
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.28),
              radius: 1.0,
              colors: [
                Color(0x33D8A84E),
                Color(0x146C3CEB),
                Colors.transparent,
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        // Minimal vignette.
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              radius: 1.05,
              colors: [Colors.transparent, Color(0x59140A08)],
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
