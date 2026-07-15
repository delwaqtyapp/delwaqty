import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/animated_slide_in.dart';
import 'package:delwaqty/shared/widgets/app_button.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                AnimatedFadeIn(
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: context.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        l10n.appNameAr,
                        style: context.textTheme.headlineLarge?.copyWith(
                          color: context.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
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
                      color: context.colorScheme.onSurface,
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
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(flex: 3),
                AnimatedSlideIn(
                  delay: const Duration(milliseconds: 600),
                  child: AppButton(
                    onPressed: () => context.pushNamed('login'),
                    isExpanded: true,
                    child: Text(l10n.welcomeLoginButton),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSlideIn(
                  delay: const Duration(milliseconds: 700),
                  child: AppButton(
                    onPressed: () => context.pushNamed('register'),
                    isExpanded: true,
                    variant: AppButtonVariant.outlined,
                    child: Text(l10n.welcomeRegisterButton),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedFadeIn(
                  delay: const Duration(milliseconds: 800),
                  child: TextButton(
                    onPressed: () {
                      // TODO: Implement guest mode
                    },
                    child: Text(
                      l10n.welcomeGuestButton,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
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
    );
  }
}
