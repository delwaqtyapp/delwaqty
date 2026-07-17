import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/animated_slide_in.dart';
import 'package:delwaqty/shared/widgets/app_button.dart';
import 'package:delwaqty/shared/widgets/app_text_field.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      return;
    }
    ref
        .read(authStateProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);

    ref.listen<AuthState>(authStateProvider, (prev, next) {
      next.whenOrNull(
        error: (message) => context.showAppSnackBar(message, isError: true),
      );
    });

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      _buildLogo(l10n),
                      const SizedBox(height: 20),
                      AnimatedSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: Text(
                          l10n.hello,
                          style: context.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSlideIn(
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          l10n.welcomeSubtitle,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _buildSocialButtons(l10n),
                      const SizedBox(height: 24),
                      _buildDivider(l10n),
                      const SizedBox(height: 24),
                      _buildEmailForm(l10n, authState),
                      const SizedBox(height: 16),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 700),
                        child: TextButton(
                          onPressed: () => context.pushNamed('register'),
                          child: Text.rich(
                            TextSpan(
                              text: '${l10n.dontHaveAccount} ',
                              children: [
                                TextSpan(
                                  text: l10n.register,
                                  style: TextStyle(
                                    color: context.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTerms(l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(AppLocalizations l10n) {
    return AnimatedFadeIn(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            l10n.appNameAr,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: context.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButtons(AppLocalizations l10n) {
    return Column(
      children: [
        AnimatedSlideIn(
          delay: const Duration(milliseconds: 300),
          beginOffset: const Offset(0, 0.15),
          child: _SocialButton(
            onPressed: () {},
            icon: Icons.g_mobiledata_rounded,
            label: l10n.loginWithGoogle,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSlideIn(
          delay: const Duration(milliseconds: 350),
          beginOffset: const Offset(0, 0.15),
          child: _SocialButton(
            onPressed: () {},
            icon: Icons.apple_rounded,
            label: l10n.loginWithApple,
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSlideIn(
          delay: const Duration(milliseconds: 400),
          beginOffset: const Offset(0, 0.15),
          child: _SocialButton(
            onPressed: () {},
            icon: Icons.facebook_rounded,
            label: l10n.loginWithFacebook,
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSlideIn(
          delay: const Duration(milliseconds: 450),
          beginOffset: const Offset(0, 0.15),
          child: _SocialButton(
            onPressed: () {},
            icon: Icons.phone_rounded,
            label: l10n.loginWithPhone,
            backgroundColor: context.colorScheme.primaryContainer,
            foregroundColor: context.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 500),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.orContinueWith,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildEmailForm(AppLocalizations l10n, AuthState authState) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = _shakeController.value < 1
            ? (1 - _shakeController.value) *
                8 *
                (_shakeController.value * 4 % 2 < 1 ? 1 : -1)
            : 0.0;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Column(
        children: [
          AnimatedSlideIn(
            delay: const Duration(milliseconds: 550),
            beginOffset: const Offset(0, 0.15),
            child: AppTextField(
              controller: _emailController,
              label: l10n.email,
              prefixIcon: const Icon(Icons.email_outlined),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AppValidators.email,
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSlideIn(
            delay: const Duration(milliseconds: 600),
            beginOffset: const Offset(0, 0.15),
            child: AppTextField(
              controller: _passwordController,
              label: l10n.password,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    key: ValueKey(_obscurePassword),
                  ),
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: AppValidators.password,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => context.pushNamed('forgot-password'),
              child: Text(l10n.forgotPassword),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSlideIn(
            delay: const Duration(milliseconds: 650),
            beginOffset: const Offset(0, 0.15),
            child: AppButton(
              onPressed: _handleLogin,
              isLoading: authState is AuthLoading,
              isExpanded: true,
              child: Text(l10n.login),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerms(AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 800),
      child: Text.rich(
        TextSpan(
          text: l10n.agreementPrefix,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
          children: [
            TextSpan(
              text: l10n.termsOfService,
              style: TextStyle(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(text: l10n.and),
            TextSpan(
              text: l10n.privacyPolicy,
              style: TextStyle(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: foregroundColor.withValues(alpha: 0.2),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusLg,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
