import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});
  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _wordController;
  late final AnimationController _taglineController;

  Timer? _navTimer;
  bool _navigated = false;

  final ValueNotifier<double> _ambientTick = ValueNotifier<double>(0);
  Ticker? _ambientTicker;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _wordController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _ambientTicker = createTicker((elapsed) {
      _ambientTick.value = elapsed.inMilliseconds / 3000.0;
    });
    _ambientTicker!.start();

    _startSequence();
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    _wordController.forward();

    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    _taglineController.forward();

    _navTimer = Timer(const Duration(milliseconds: 2000), _navigate);
  }

  void _navigate() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    // The router enforces the App Lock gate (device-unlock screen) when a
    // locally stored account exists, so we just hand off to the login route.
    context.go('/login');
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _ambientTicker?.stop();
    _ambientTicker?.dispose();
    _ambientTick.dispose();
    _logoController.dispose();
    _wordController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF241E44),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF241E44),
              Color(0xFF2C2558),
              Color(0xFF1E1940),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _GlowPainter(),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: _ambientTick,
                  builder: (context, progress, _) => CustomPaint(
                    painter: _ParticlePainter(progress: progress),
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 36),
                  _buildWordmark(),
                  const SizedBox(height: 16),
                  _buildTagline(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, _) {
        final p = _logoController.value;
        final eased = Curves.easeOutBack.transform(p);
        final scale = 0.7 + eased * 0.3;

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: p,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7A5CFF).withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/logo app/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7A5CFF), Color(0xFF2DD4BF)],
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordmark() {
    return AnimatedBuilder(
      animation: _wordController,
      builder: (context, _) {
        final p = _wordController.value;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLetter('D', 0.0, 0.2, p, Colors.white, 38),
              _buildLetter('e', 0.08, 0.28, p, Colors.white, 38),
              _buildLetter('l', 0.16, 0.36, p, Colors.white, 38),
              _buildLetter('w', 0.24, 0.44, p, Colors.white, 38),
              _buildLetter('a', 0.32, 0.52, p, Colors.white, 38),
              _buildRotatingLetter('Q', 0.4, 0.6, p, const Color(0xFF7A5CFF), 42),
              _buildLetter('t', 0.55, 0.75, p, const Color(0xFF4E8DFF), 38),
              _buildLetter('y', 0.65, 0.85, p, const Color(0xFF2DD4BF), 38),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLetter(
    String char,
    double start,
    double end,
    double progress,
    Color color,
    double fontSize,
  ) {
    final t = ((progress - start) / (end - start)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(8 * (1 - eased), 0),
        child: Text(
          char,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildRotatingLetter(
    String char,
    double start,
    double end,
    double progress,
    Color color,
    double fontSize,
  ) {
    final t = ((progress - start) / (end - start)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(t);
    final rotation = (1 - t) * 15 * (math.pi / 180);
    final scale = t < 0.5 ? 0.8 + t * 0.6 : 1.1 - (t - 0.5) * 0.2;
    return Opacity(
      opacity: eased,
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale.clamp(0.8, 1.15),
          child: Text(
            char,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _taglineController,
      builder: (context, _) {
        final p = _taglineController.value;
        final part1Opacity = (p * 3).clamp(0.0, 1.0);
        final part2Opacity = ((p - 0.5) * 2).clamp(0.0, 1.0);

        return Column(
          children: [
            Opacity(
              opacity: part1Opacity,
              child: Text(
                l10n.splashTagline,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.6 * part1Opacity),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Opacity(
              opacity: part2Opacity,
              child: RichText(
                textDirection: TextDirection.rtl,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  children: [
                    TextSpan(text: 'د', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'ل', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'و', style: TextStyle(color: Colors.white)),
                    TextSpan(text: 'ق', style: TextStyle(color: Color(0xFF7A5CFF))),
                    TextSpan(text: 'ت', style: TextStyle(color: Color(0xFF4E8DFF))),
                    TextSpan(text: 'ي', style: TextStyle(color: Color(0xFF2DD4BF))),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);

    canvas.drawCircle(
      center,
      220,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          220,
          [
            const Color(0xFF7A5CFF).withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
    );

    final p2 = Offset(size.width * 0.2, size.height * 0.6);
    canvas.drawCircle(
      p2,
      160,
      Paint()
        ..shader = ui.Gradient.radial(
          p2,
          160,
          [
            const Color(0xFF2DD4BF).withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ),
    );

    final p3 = Offset(size.width * 0.85, size.height * 0.55);
    canvas.drawCircle(
      p3,
      120,
      Paint()
        ..shader = ui.Gradient.radial(
          p3,
          120,
          [
            const Color(0xFF4E8DFF).withValues(alpha: 0.03),
            Colors.transparent,
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) => false;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress});

  final double progress;

  static final _particleCache = <_ParticleData>[];
  static int _cacheSeed = -1;

  @override
  void paint(Canvas canvas, Size size) {
    if (_cacheSeed != 7) {
      _particleCache.clear();
      final rng = math.Random(7);
      for (var i = 0; i < 30; i++) {
        _particleCache.add(_ParticleData(
          baseX: rng.nextDouble(),
          baseY: rng.nextDouble(),
          speed: 0.2 + rng.nextDouble() * 0.5,
          phase: rng.nextDouble() * 2 * math.pi,
          radius: 1.0 + rng.nextDouble() * 1.5,
        ));
      }
      _cacheSeed = 7;
    }

    for (var i = 0; i < _particleCache.length; i++) {
      final p = _particleCache[i];
      final baseX = p.baseX * size.width;
      final baseY = p.baseY * size.height;
      final t = (progress * p.speed * 3 + p.phase) % 1.0;
      final yOff = math.sin(t * 2 * math.pi) * 20;
      final opacity = math.sin(t * math.pi) * 0.18;

      if (opacity > 0.01) {
        canvas.drawCircle(
          Offset(baseX, baseY + yOff),
          p.radius,
          Paint()..color = Colors.white.withValues(alpha: opacity),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.progress != progress;
}

class _ParticleData {
  const _ParticleData({
    required this.baseX,
    required this.baseY,
    required this.speed,
    required this.phase,
    required this.radius,
  });
  final double baseX;
  final double baseY;
  final double speed;
  final double phase;
  final double radius;
}
