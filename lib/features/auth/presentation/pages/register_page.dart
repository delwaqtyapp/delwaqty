import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/shared/widgets/app_button.dart';
import 'package:delwaqty/shared/widgets/app_text_field.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authStateProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
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
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.register,
                      style: context.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AppTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          AppValidators.required(v, 'Full name'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _emailController,
                      label: l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: AppValidators.email,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      validator: AppValidators.password,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () =>
                              _obscureConfirmPassword = !_obscureConfirmPassword,
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      validator: (v) => AppValidators.confirmPassword(
                        v,
                        _passwordController.text,
                      ),
                      onFieldSubmitted: (_) => _handleRegister(),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      onPressed: _handleRegister,
                      isLoading: authState is AuthLoading,
                      isExpanded: true,
                      child: Text(l10n.register),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          children: [
                            TextSpan(
                              text: l10n.login,
                              style: TextStyle(
                                color: context.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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
