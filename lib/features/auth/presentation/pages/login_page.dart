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

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authStateProvider.notifier).signIn(
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
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 64,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.hello,
                      style: context.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
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
                      textInputAction: TextInputAction.done,
                      validator: AppValidators.password,
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => context.pushNamed('forgot-password'),
                        child: Text(l10n.forgotPassword),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      onPressed: _handleLogin,
                      isLoading: authState is AuthLoading,
                      isExpanded: true,
                      child: Text(l10n.login),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pushNamed('register'),
                      child: Text.rich(
                        TextSpan(
                          text: "Don't have an account? ",
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
