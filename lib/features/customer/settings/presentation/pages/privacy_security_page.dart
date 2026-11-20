import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class PrivacySecurityPage extends ConsumerWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colorScheme;
    final authState = ref.watch(authStateProvider);
    final isBiometricEnabled = authState.whenOrNull(
          authenticated: (user) => user.isBiometricEnabled,
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacySecurity),
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(context, l10n),
          const SizedBox(height: 20),
          _buildSection(
            context,
            title: l10n.security,
            children: [
              _buildNavTile(
                context,
                icon: Icons.lock_outline_rounded,
                title: l10n.changePassword,
                onTap: () => context.push('/settings/change-password'),
              ),
              _buildDivider(cs),
              _buildNavTile(
                context,
                icon: Icons.fingerprint_rounded,
                title: l10n.fingerprintLogin,
                subtitle: l10n.fingerprintLoginDescription,
                trailingWidget: _StatusPill(
                  label: isBiometricEnabled ? l10n.active : l10n.inactive,
                  isActive: isBiometricEnabled,
                ),
                onTap: () => context.push('/settings/fingerprint-login'),
              ),
              _buildDivider(cs),
              _buildNavTile(
                context,
                icon: Icons.history_rounded,
                title: l10n.loginActivity,
                onTap: () => context.push('/settings/login-activity'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            title: l10n.privacy,
            children: [
              _buildNavTile(
                context,
                icon: Icons.location_on_outlined,
                title: l10n.locationSharing,
                onTap: () => context.push('/settings/location-sharing'),
              ),
              _buildDivider(cs),
              _buildNavTile(
                context,
                icon: Icons.notifications_outlined,
                title: l10n.notificationPreferences,
                onTap: () => context.push('/settings/notification-preferences'),
              ),
              _buildDivider(cs),
              _buildNavTile(
                context,
                icon: Icons.storage_outlined,
                title: l10n.dataPrivacy,
                onTap: () => context.push('/settings/data-privacy'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            title: l10n.about,
            children: [
              _buildNavTile(
                context,
                icon: Icons.privacy_tip_outlined,
                title: l10n.privacyPolicy,
                onTap: () => context.push('/settings/privacy-policy'),
              ),
              _buildDivider(cs),
              _buildNavTile(
                context,
                icon: Icons.description_outlined,
                title: l10n.termsOfService,
                onTap: () => context.push('/settings/terms-of-service'),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.brandPurpleDeep,
            AppColors.brandPurple,
            AppColors.brandViolet,
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPurple.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.brandGold.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.privacySecurity,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.security} • ${l10n.privacy}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final cs = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandPurple, AppColors.brandViolet],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: cs.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailingWidget,
    required VoidCallback onTap,
  }) {
    final cs = context.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(
        title,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingWidget != null) ...[
            trailingWidget,
            const SizedBox(width: 6),
          ],
          Icon(
            Icons.chevron_right_rounded,
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(ColorScheme cs) {
    return Divider(
      height: 1,
      indent: 66,
      endIndent: 16,
      color: cs.outlineVariant.withValues(alpha: 0.35),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.isActive,
  });

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final color = isActive ? AppColors.successLight : cs.onSurfaceVariant;
    final bg = isActive
        ? AppColors.successLight.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
