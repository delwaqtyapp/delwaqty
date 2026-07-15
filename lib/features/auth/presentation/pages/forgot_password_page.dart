import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/shared/widgets/app_button.dart';
import 'package:delwaqty/shared/widgets/app_text_field.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
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
      await ref.read(authStateProvider.notifier).resetPassword(
            email: _emailController.text.trim(),
          );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showAppSnackBar(e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _emailSent
                  ? Column(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 64,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.resetPassword,
                          style: context.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A password reset link has been sent to your email.',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          onPressed: () => context.goNamed('login'),
                          isExpanded: true,
                          child: Text(l10n.login),
                        ),
                      ],
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.lock_reset_outlined,
                            size: 64,
                            color: context.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.forgotPassword,
                            style: context.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your email address and we will send you a link to reset your password.',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          AppTextField(
                            controller: _emailController,
                            label: l10n.email,
                            prefixIcon: const Icon(Icons.email_outlined),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            validator: AppValidators.email,
                            onFieldSubmitted: (_) => _handleResetPassword(),
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            onPressed: _handleResetPassword,
                            isLoading: _isLoading,
                            isExpanded: true,
                            child: Text(l10n.submit),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
