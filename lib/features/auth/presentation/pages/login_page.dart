import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _savedEmail = '';
  final LocalAuthentication _localAuth = LocalAuthentication();
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    ref.read(authStateProvider.notifier).signIn(
          email: email,
          password: password,
        );

    if (_rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.biometricEmail, email);
      await prefs.setString(StorageKeys.biometricPassword, password);
      if (_biometricAvailable) {
        await prefs.setBool(StorageKeys.biometricEnabled, true);
        if (mounted) setState(() => _biometricEnabled = true);
      }
    }
  }

  Future<void> _checkBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(StorageKeys.biometricEnabled) ?? false;
      final email = prefs.getString(StorageKeys.biometricEmail) ?? '';
      if (mounted) {
        setState(() {
          _biometricAvailable = canCheck;
          _biometricEnabled = enabled && email.isNotEmpty;
          _savedEmail = email;
        });
      }
    } catch (_) {}
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: AppLocalizations.of(context).biometricReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (didAuth && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString(StorageKeys.biometricEmail) ?? '';
        final password = prefs.getString(StorageKeys.biometricPassword) ?? '';
        if (email.isNotEmpty && password.isNotEmpty) {
          ref.read(authStateProvider.notifier).signIn(
                email: email,
                password: password,
              );
        } else if (email.isNotEmpty) {
          _emailController.text = email;
          context.showAppSnackBar(
            AppLocalizations.of(context).enterPasswordForFingerprint,
          );
        }
      }
    } on PlatformException catch (_) {
      if (mounted) {
        context.showAppSnackBar(AppLocalizations.of(context).biometricFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);

    ref.listen<AuthState>(authStateProvider, (prev, next) {
      next.whenOrNull(
        authenticated: (_) => context.go('/home'),
        guest: () => context.go('/home'),
        error: (msg) => context.showAppSnackBar(msg),
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final shake = sin(_shakeAnimation.value * 3 * 3.14159) *
                    8 *
                    (1 - _shakeAnimation.value);
                return Transform.translate(
                  offset: Offset(shake, 0),
                  child: child,
                );
              },
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _fadeController,
                  curve: Curves.easeOut,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.vertical,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        _buildLogo(),
                        const SizedBox(height: 28),
                        _buildWelcome(l10n),
                        const SizedBox(height: 8),
                        _buildSubtitle(l10n),
                        const SizedBox(height: 40),
                        _buildForm(l10n, authState),
                        const SizedBox(height: 28),
                        _buildDivider(l10n),
                        const SizedBox(height: 20),
                        _buildSocialButtons(l10n),
                        const SizedBox(height: 20),
                        _buildGuestButton(l10n),
                        const SizedBox(height: 20),
                        _buildRegisterLink(l10n),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
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
            child: _floatingCircle(180, AppColors.brandPurple, 0.06),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: _floatingCircle(140, AppColors.brandCyan, 0.04),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            right: -30,
            child: _floatingCircle(100, AppColors.brandPurple, 0.03),
          ),
        ],
      ),
    );
  }

  Widget _floatingCircle(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'app_logo',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (context, value, _) {
          return Transform.scale(
            scale: 0.8 + value * 0.2,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandPurple.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/logo app/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.brandPurple, AppColors.brandCyan],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcome(AppLocalizations l10n) {
    return Text(
      l10n.hello,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1035),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildSubtitle(AppLocalizations l10n) {
    return Text(
      l10n.welcomeSubtitle,
      style: TextStyle(
        fontSize: 14,
        color: const Color(0xFF1A1035).withValues(alpha: 0.5),
        letterSpacing: 0.3,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildForm(AppLocalizations l10n, AuthState authState) {
    final isLoading = authState is AuthLoading;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _LightTextField(
            controller: _emailController,
            hint: l10n.emailOrPhone,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => AppValidators.email(v),
          ),
          const SizedBox(height: 14),
          _LightTextField(
            controller: _passwordController,
            hint: l10n.password,
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            validator: (v) => AppValidators.password(v),
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF1A1035).withValues(alpha: 0.3),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                      activeColor: AppColors.brandPurple,
                      side: BorderSide(
                        color:
                            const Color(0xFF1A1035).withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.rememberMe,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          const Color(0xFF1A1035).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/forgot-password'),
                child: Text(
                  l10n.forgotPassword,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.brandPurple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _LoginButton(
            onPressed: isLoading ? null : _onLogin,
            isLoading: isLoading,
            label: l10n.signIn,
          ),
          if (_biometricAvailable && _biometricEnabled) ...[
            const SizedBox(height: 16),
            _BiometricButton(
              onPressed: _authenticateWithBiometric,
              savedEmail: _savedEmail,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFF1A1035).withValues(alpha: 0.08),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.or,
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF1A1035).withValues(alpha: 0.35),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFF1A1035).withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: _SocialButtonLight(
            icon: Icons.g_mobiledata_rounded,
            label: 'Google',
            onTap: () =>
                ref.read(authStateProvider.notifier).signInWithGoogle(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButtonLight(
            icon: Icons.apple_rounded,
            label: 'Apple',
            onTap: () =>
                ref.read(authStateProvider.notifier).signInWithApple(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButtonLight(
            icon: Icons.facebook_rounded,
            label: 'Facebook',
            onTap: () =>
                ref.read(authStateProvider.notifier).signInWithFacebook(),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(authStateProvider.notifier).enterGuestMode();
          context.go('/home');
        },
        icon: Icon(
          Icons.person_outline_rounded,
          color: const Color(0xFF1A1035).withValues(alpha: 0.5),
          size: 20,
        ),
        label: Text(
          l10n.continueAsGuest,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A1035).withValues(alpha: 0.55),
            letterSpacing: 0.2,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: const Color(0xFF1A1035).withValues(alpha: 0.1),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildRegisterLink(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.dontHaveAccount,
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF1A1035).withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => context.push('/register'),
          child: const Text(
            'Register',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.brandPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LightTextField extends StatelessWidget {
  const _LightTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Color(0xFF1A1035), fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: const Color(0xFF1A1035).withValues(alpha: 0.3),
          fontSize: 15,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF1A1035).withValues(alpha: 0.35),
          size: 20,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFF1A1035).withValues(alpha: 0.06),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
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
      width: double.infinity,
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
          color: onPressed == null
              ? const Color(0xFF1A1035).withValues(alpha: 0.08)
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

class _SocialButtonLight extends StatelessWidget {
  const _SocialButtonLight({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.brandPurple.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1A1035).withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF1A1035).withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1035).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({
    required this.onPressed,
    this.savedEmail = '',
  });

  final VoidCallback onPressed;
  final String savedEmail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.brandPurple.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPurple.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                color: AppColors.brandPurple.withValues(alpha: 0.7),
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              savedEmail.isNotEmpty ? savedEmail : AppLocalizations.of(context).fingerprintLogin,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF1A1035).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
