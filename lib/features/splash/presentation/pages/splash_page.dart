import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});
  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _glowController;
  late final AnimationController _textController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;
  late final AnimationController _gradientController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _gradientAngle;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _gradientAngle = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.linear),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _glowController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _textController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    final onboardingComplete = sharedPrefs.getBool(
      key: StorageKeys.onboardingComplete,
    );
    if (!mounted) return;
    if (onboardingComplete != true) {
      context.go('/onboarding');
      return;
    }
    final authState = ref.read(authStateProvider);
    if (authState is AuthAuthenticated) {
      context.go('/home');
    } else {
      context.go('/welcome');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientAngle,
        builder: (context, child) {
          final angle = _gradientAngle.value;
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(
                  math.cos(angle),
                  math.sin(angle),
                ),
                end: Alignment(
                  -math.cos(angle),
                  -math.sin(angle),
                ),
                colors: const [
                  Color(0xFF6750A4),
                  Color(0xFF9A82DB),
                  Color(0xFF6750A4),
                  Color(0xFFD0BCFF),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
            child: Stack(
              children: [
                ...List.generate(30, (i) => _buildParticle(i, size)),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGlowRing(),
                      const SizedBox(height: 40),
                      _buildLogo(l10n),
                      const SizedBox(height: 32),
                      _buildTitle(l10n),
                      const SizedBox(height: 8),
                      _buildTagline(l10n),
                      const SizedBox(height: 60),
                      _buildLoader(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlowRing() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 220 + (_glowAnimation.value * 30),
          height: 220 + (_glowAnimation.value * 30),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.12 * _glowAnimation.value),
                blurRadius: 80 * _glowAnimation.value,
                spreadRadius: 25 * _glowAnimation.value,
              ),
              BoxShadow(
                color: const Color(0xFFD0BCFF).withValues(
                  alpha: 0.08 * _glowAnimation.value,
                ),
                blurRadius: 120 * _glowAnimation.value,
                spreadRadius: 40 * _glowAnimation.value,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogo(AppLocalizations l10n) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: const Color(0xFFD0BCFF).withValues(alpha: 0.4),
              blurRadius: 60,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            l10n.appNameAr,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6750A4),
              letterSpacing: -1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(AppLocalizations l10n) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _fadeAnimation.value)),
            child: child,
          ),
        );
      },
      child: Text(
        l10n.appTitle,
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTagline(AppLocalizations l10n) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value * 0.85,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - _fadeAnimation.value)),
            child: child,
          ),
        );
      },
      child: Text(
        l10n.splashTagline,
        style: TextStyle(
          fontSize: 16,
          color: Colors.white.withValues(alpha: 0.8),
          letterSpacing: 1.5,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildParticle(int index, Size size) {
    final rng = math.Random(index);
    final particleSize = 2.0 + rng.nextDouble() * 4;
    final x = rng.nextDouble() * size.width;
    final y = rng.nextDouble() * size.height;
    final speed = 2000 + rng.nextInt(3000);
    final delay = rng.nextInt(3000);

    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final t = ((_particleController.value * speed + delay) % speed) / speed;
        final opacity = (math.sin(t * math.pi) * 0.4).clamp(0.0, 0.4);
        final yOffset = t * -60;

        return Positioned(
          left: x,
          top: y + yOffset,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: particleSize,
              height: particleSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: opacity * 0.5),
                    blurRadius: particleSize * 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
