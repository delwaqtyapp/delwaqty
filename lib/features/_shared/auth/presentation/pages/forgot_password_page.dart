import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authStateProvider.notifier)
          .resetPassword(email: _emailController.text.trim());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.of(context);
        context.showAppSnackBar(l10n.somethingWentWrong, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _emailSent
                      ? _buildSuccessView(l10n)
                      : _buildFormView(l10n),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8F6FF),
            Color(0xFFEFEBFF),
            Color(0xFFF5F3FF),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandPurple.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandCyan.withValues(alpha: 0.04),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, value, _) {
            return Transform.scale(
              scale: 0.5 + value * 0.5,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brandPurple.withValues(alpha: 0.15),
                      AppColors.brandCyan.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 55,
                  color: AppColors.brandPurple,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        Text(
          l10n.resetPassword,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1035),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.resetEmailSent,
          style: TextStyle(
            fontSize: 15,
            color: const Color(0xFF1A1035).withValues(alpha: 0.5),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _PurpleButton(
          onPressed: () => context.go('/login'),
          label: l10n.backToLogin,
        ),
      ],
    );
  }

  Widget _buildFormView(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.brandPurple.withValues(alpha: 0.15),
                  AppColors.brandCyan.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: const Icon(
              Icons.lock_reset_outlined,
              size: 55,
              color: AppColors.brandPurple,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.forgotPassword,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1035),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.resetEmailHint,
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF1A1035).withValues(alpha: 0.5),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: AppValidators.email,
            onFieldSubmitted: (_) => _handleResetPassword(),
            style: const TextStyle(color: Color(0xFF1A1035), fontSize: 15),
            decoration: InputDecoration(
              hintText: l10n.email,
              hintStyle: TextStyle(
                color: const Color(0xFF1A1035).withValues(alpha: 0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: const Color(0xFF1A1035).withValues(alpha: 0.35),
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: const Color(0xFF1A1035).withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: const Color(0xFF1A1035).withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.brandPurple,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _PurpleButton(
            onPressed: _isLoading ? null : _handleResetPassword,
            isLoading: _isLoading,
            label: l10n.resetPassword,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              l10n.backToLogin,
              style: const TextStyle(
                color: AppColors.brandPurple,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurpleButton extends StatelessWidget {
  const _PurpleButton({
    required this.onPressed,
    required this.label,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? const LinearGradient(
                  colors: [
                    AppColors.brandPurple,
                    Color(0xFF6B5CE7),
                  ],
                )
              : null,
          color: onPressed == null ? const Color(0xFF1A1035).withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: AppColors.brandPurple.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(22),
            splashColor: Colors.white.withValues(alpha: 0.1),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
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
        ),
      ),
    );
  }
}
