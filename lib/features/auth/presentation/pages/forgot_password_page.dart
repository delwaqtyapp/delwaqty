import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/animated_slide_in.dart';
import 'package:delwaqty/shared/widgets/app_button.dart';
import 'package:delwaqty/shared/widgets/app_text_field.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
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
      body: GradientBackground(
        child: SafeArea(
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
      ),
    );
  }

  Widget _buildSuccessView(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedFadeIn(
          duration: const Duration(milliseconds: 800),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 60,
              color: context.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 32),
        AnimatedSlideIn(
          delay: const Duration(milliseconds: 200),
          child: Text(
            l10n.resetPassword,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSlideIn(
          delay: const Duration(milliseconds: 400),
          child: Text(
            l10n.resetEmailSent,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        AnimatedSlideIn(
          delay: const Duration(milliseconds: 600),
          beginOffset: const Offset(0, 0.2),
          child: AppButton(
            onPressed: () => context.goNamed('login'),
            isExpanded: true,
            child: Text(l10n.backToLogin),
          ),
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
          AnimatedFadeIn(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_reset_outlined,
                size: 60,
                color: context.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          AnimatedSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Text(
              l10n.forgotPassword,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSlideIn(
            delay: const Duration(milliseconds: 200),
            child: Text(
              l10n.resetEmailHint,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          AnimatedSlideIn(
            delay: const Duration(milliseconds: 300),
            beginOffset: const Offset(0, 0.2),
            child: AppTextField(
              controller: _emailController,
              label: l10n.email,
              prefixIcon: const Icon(Icons.email_outlined),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: AppValidators.email,
              onFieldSubmitted: (_) => _handleResetPassword(),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSlideIn(
            delay: const Duration(milliseconds: 400),
            beginOffset: const Offset(0, 0.2),
            child: AppButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              isLoading: _isLoading,
              isExpanded: true,
              child: Text(l10n.resetPassword),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 500),
            child: TextButton(
              onPressed: () => context.pop(),
              child: Text(l10n.backToLogin),
            ),
          ),
        ],
      ),
    );
  }
}
