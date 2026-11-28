import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Google sign-in with an "or continue with" divider.
///
/// Registration supports Google or WhatsApp-verified phone only.
/// The OAuth use cases and the `io.delwaqty://login-callback` deep-link
/// return path already exist in the data layer; this widget is the UI entry
/// point. White cards keep the brand logos readable on both the gradient
/// welcome background and the cinematic auth backgrounds.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.onGoogle,
    this.onFacebook,
    this.isLoading = false,
    this.dividerColor,
  });

  final VoidCallback onGoogle;

  /// Shown only when the server turned Facebook on (auth_methods).
  final VoidCallback? onFacebook;

  /// Disables the button while an auth flow is in progress.
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
        if (onFacebook != null) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onFacebook,
            icon: const Icon(Icons.facebook_rounded),
            label: Text(l10n.loginWithFacebook),
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
