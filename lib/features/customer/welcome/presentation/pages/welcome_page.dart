import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/router/post_auth_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/animated_slide_in.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/shared/widgets/cinematic_auth_background.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
import 'package:delwaqty/shared/widgets/social_auth_buttons.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0614),
      body: Stack(
        children: [
          const CinematicAuthBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32),
                  AnimatedFadeIn(
                    duration: const Duration(milliseconds: 1000),
                    child: Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D5B3DF0),
                              blurRadius: 40,
                              offset: Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Color(0x26D8A84E),
                              blurRadius: 24,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            'assets/logo app/logo.webp',
                            width: 84,
                            height: 84,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                l10n.appNameAr,
                                style: AppTextStyles.headlineLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      l10n.welcomeTitle,
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.onPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSlideIn(
                    delay: const Duration(milliseconds: 400),
                    child: Text(
                      l10n.welcomeSubtitle,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colorScheme.onPrimary.withValues(
                          alpha: 0.85,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(flex: 3),
                  AnimatedSlideIn(
                    delay: const Duration(milliseconds: 600),
                    child: _WelcomePrimaryButton(
                      onPressed: () => context.pushNamed('login'),
                      label: l10n.welcomeLoginButton,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSlideIn(
                    delay: const Duration(milliseconds: 700),
                    child: _WelcomeOutlineButton(
                      onPressed: () => context.pushNamed('register'),
                      label: l10n.welcomeRegisterButton,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSlideIn(
                    delay: const Duration(milliseconds: 750),
                    child: SocialAuthButtons(
                      onGoogle: () => ref
                          .read(authStateProvider.notifier)
                          .signInWithGoogle(),
                      dividerColor: context.colorScheme.onPrimary.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 800),
                    child: TextButton(
                      onPressed: () {
                        ref.read(authStateProvider.notifier).enterGuestMode();
                        context.go(postAuthRoute(ref.read(appFlavorProvider)));
                      },
                      child: Text(
                        l10n.welcomeGuestButton,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: context.colorScheme.onPrimary.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary CTA matching the login page's gradient button (58px, radius 22).
class _WelcomePrimaryButton extends StatelessWidget {
  const _WelcomePrimaryButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scale: 0.98,
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.brandPurple, Color(0xFF6B5CE7)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPurple.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary CTA matching the login page's glass/outline language.
class _WelcomeOutlineButton extends StatelessWidget {
  const _WelcomeOutlineButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scale: 0.98,
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
