import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Kills Facebook sign-in UI while the Meta app lacks business
/// verification (owner decision 2026-11-21: no سجل تجاري yet, registration
/// runs on phone number + WhatsApp OTP only). Flip back to `true` to
/// re-enable - the data layer (OAuth use cases, deep-link callback) is
/// untouched and works as before.
const bool kFacebookLoginEnabled = false;

/// Google + Facebook sign-in buttons with an "or continue with" divider.
///
/// The OAuth use cases and the `io.delwaqty://login-callback` deep-link
/// return path already exist in the data layer; this widget is the UI entry
/// point. White cards keep the brand logos readable on both the gradient
/// welcome background and the cinematic auth backgrounds.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.onGoogle,
    required this.onFacebook,
    this.isLoading = false,
    this.dividerColor,
  });

  final VoidCallback onGoogle;
  final VoidCallback onFacebook;

  /// Disables both buttons while any auth flow is in progress.
  final bool isLoading;

  /// Divider/label color; defaults to the theme's outline color. Pass a
  /// light color when the widget sits on a dark gradient.
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveDividerColor =
        dividerColor ?? Theme.of(context).colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: effectiveDividerColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                l10n.orContinueWith,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: AppTextStyles.labelMedium.copyWith(
                  color: effectiveDividerColor,
                  letterSpacing: 0,
                  height: 1.8,
                ),
              ),
            ),
            Expanded(child: Divider(color: effectiveDividerColor)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _SocialButton(
          onPressed: isLoading ? null : onGoogle,
          logoAsset: 'assets/branding/google_logo.png',
          label: l10n.loginWithGoogle,
        ),
        if (kFacebookLoginEnabled) ...[
          const SizedBox(height: AppSpacing.sm),
          _SocialButton(
            onPressed: isLoading ? null : onFacebook,
            logoAsset: 'assets/branding/facebook_logo.png',
            label: l10n.loginWithFacebook,
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onPressed,
    required this.logoAsset,
    required this.label,
  });

  final VoidCallback? onPressed;
  final String logoAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppSpacing.borderRadiusLg,
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppSpacing.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                logoAsset,
                width: 22,
                height: 22,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.login, size: 22, color: Colors.black54),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
