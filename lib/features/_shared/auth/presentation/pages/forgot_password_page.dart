import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/widgets/whatsapp_otp_sheet.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final whatsappResetVerifierProvider =
    Provider<Future<String?> Function(BuildContext, String)>((ref) {
      return (context, phone) => WhatsAppOtpSheet.showChallenge(
        context,
        phone: phone,
        purpose: 'password_reset',
      );
    });

final whatsappPasswordResetProvider =
    Provider<Future<void> Function(String, String, String)>((ref) {
      return (phone, challenge, password) async {
        final response = await Supabase.instance.client.functions.invoke(
          'whatsapp-password-reset',
          body: {
            'phone': phone,
            'challenge': challenge,
            'new_password': password,
          },
        );
        if (response.status != 200 ||
            response.data is! Map ||
            response.data['ok'] != true) {
          throw StateError('Password reset not confirmed');
        }
      };
    });

/// Reset with a one-time code an admin gave over the phone (used while the
/// WhatsApp proof is switched off). The server checks the hashed code.
final recoveryCodeResetProvider =
    Provider<Future<void> Function(String, String, String)>((ref) {
      return (phone, code, password) async {
        final response = await Supabase.instance.client.functions.invoke(
          'recovery-code-reset',
          body: {'phone': phone, 'code': code, 'new_password': password},
        );
        if (response.status != 200 ||
            response.data is! Map ||
            response.data['ok'] != true) {
          throw StateError('Password reset not confirmed');
        }
      };
    });

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _codeController = TextEditingController();
  String? _challenge;
  bool _resetDone = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final codeMode =
          ref.read(signupPhoneModeProvider).asData?.value == 'password';
      if (codeMode) {
        await ref.read(recoveryCodeResetProvider)(
          _phoneController.text.trim(),
          _codeController.text.trim(),
          _passwordController.text,
        );
        if (mounted) setState(() => _resetDone = true);
        return;
      }
      if (_challenge == null) {
        final challenge = await ref.read(whatsappResetVerifierProvider)(
          context,
          _phoneController.text.trim(),
        );
        if (mounted) setState(() => _challenge = challenge);
        return;
      }
      await ref.read(whatsappPasswordResetProvider)(
        _phoneController.text.trim(),
        _challenge!,
        _passwordController.text,
      );
      if (mounted) setState(() => _resetDone = true);
    } catch (_) {
      if (mounted) {
        // A failed server update can burn its one-time ticket. Require a fresh
        // WhatsApp confirmation instead of replaying or faking success.
        setState(() => _challenge = null);
        context.showAppSnackBar(
          AppLocalizations.of(context).somethingWentWrong,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      PressableScale(
                        scale: 0.92,
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/login');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.75,
                            ),
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _resetDone
                            ? _buildSuccessView(l10n)
                            : _buildFormView(l10n),
                      ),
                    ),
                  ),
                ),
              ],
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
            AppColors.brandLavenderSoft,
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
                  Icons.check_circle_outline_rounded,
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
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.resetEmailSent,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary.withValues(alpha: 0.5),
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

  InputDecoration _inputDecoration(
    String hint,
    IconData icon,
  ) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: AppColors.textPrimary.withValues(alpha: 0.3),
      fontSize: 15,
    ),
    prefixIcon: Icon(
      icon,
      color: AppColors.textPrimary.withValues(alpha: 0.35),
      size: 20,
    ),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: AppColors.textPrimary.withValues(alpha: 0.08),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: AppColors.textPrimary.withValues(alpha: 0.08),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.brandPurple, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
  );

  Widget _buildFormView(AppLocalizations l10n) {
    final codeMode =
        ref.watch(signupPhoneModeProvider).asData?.value == 'password';
    final showNewPassword = codeMode || _challenge != null;
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
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            codeMode ? l10n.recoveryCodeHint : l10n.resetEmailHint,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            readOnly: _challenge != null && !codeMode,
            textInputAction: TextInputAction.done,
            validator: AppValidators.phone,
            onFieldSubmitted: (_) => _handleResetPassword(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: _inputDecoration(
              l10n.phoneNumber,
              Icons.phone_outlined,
            ),
          ),
          if (codeMode) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: _inputDecoration(
                l10n.recoveryCodeLabel,
                Icons.pin_outlined,
              ),
              validator: (value) =>
                  RegExp(r'^[0-9]{8}$').hasMatch((value ?? '').trim())
                  ? null
                  : l10n.recoveryCodeLabel,
            ),
          ],
          if (showNewPassword) ...[
            const SizedBox(height: 24),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: _inputDecoration(
                l10n.newPassword,
                Icons.lock_outline_rounded,
              ),
              validator: (value) {
                final error = AppValidators.password(value);
                if (error != null) return error;
                return (value?.length ?? 0) < 8 ? l10n.passwordTooShort : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              decoration: _inputDecoration(
                l10n.confirmPassword,
                Icons.lock_outline_rounded,
              ),
              validator: (value) => AppValidators.confirmPassword(
                value,
                _passwordController.text,
              ),
            ),
            if (!codeMode)
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _challenge = null),
                child: Text(l10n.edit),
              ),
          ],
          const SizedBox(height: 24),
          _PurpleButton(
            onPressed: _isLoading ? null : _handleResetPassword,
            isLoading: _isLoading,
            label: (_challenge == null && !codeMode)
                ? l10n.verifyViaWhatsApp
                : l10n.resetPassword,
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
                  colors: [AppColors.brandPurple, Color(0xFF6B5CE7)],
                )
              : null,
          color: onPressed == null
              ? AppColors.textPrimary.withValues(alpha: 0.08)
              : null,
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
