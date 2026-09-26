import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/constants/app_constants.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/localization/admin_locale_provider.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/services/ota/ota_update_dialog.dart';
import 'package:delwaqty/services/ota/ota_update_manager.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AdminSettingsMenuPage extends ConsumerStatefulWidget {
  const AdminSettingsMenuPage({super.key});

  @override
  ConsumerState<AdminSettingsMenuPage> createState() =>
      _AdminSettingsMenuPageState();
}

class _AdminSettingsMenuPageState extends ConsumerState<AdminSettingsMenuPage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final client = Supabase.instance.client;
      final email = client.auth.currentUser?.email ?? '';
      final isOwner = ref.read(adminIsOwnerProvider).value ?? false;

      final result = await client.rpc('get_admin_profile', params: {
        'p_email': email,
      });

      if (mounted) {
        setState(() {
          _profile = {
            'email': email,
            'is_owner': isOwner,
            ...((result as Map<String, dynamic>?) ?? {}),
          };
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _profile = {
            'email': Supabase.instance.client.auth.currentUser?.email ?? '',
            'is_owner': false,
            'role': 'admin',
            'region_name': null,
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final adminLocale = ref.watch(adminLocaleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminSettingsMenu)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GradientBackground(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AnimatedFadeIn(
                    child: _buildProfileHeader(context, l10n),
                  ),
                  const SizedBox(height: 16),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 80),
                    child: _buildAppearanceSection(
                      context,
                      l10n,
                      themeMode,
                      adminLocale,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 120),
                    child: _buildAdministrationSection(context, l10n),
                  ),
                  const SizedBox(height: 16),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 160),
                    child: _buildPlatformSection(context, l10n),
                  ),
                  const SizedBox(height: 16),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 200),
                    child: _buildAccountSection(context, l10n),
                  ),
                  const SizedBox(height: 24),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 240),
                    child: _buildLogoutButton(context),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AppLocalizations l10n) {
    final email = _profile!['email'] as String? ?? '';
    final isOwner = _profile!['is_owner'] as bool? ?? false;
    final regionName = _profile!['region_name'] as String?;
    final role = _profile!['role'] as String? ?? 'admin';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOwner ? Colors.amber : Theme.of(context).colorScheme.primaryContainer,
                border: Border.all(
                  color: isOwner
                      ? Colors.amber.shade600
                      : Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isOwner ? Colors.amber : Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.transparent,
                child: Icon(
                  isOwner ? Icons.star_rounded : Icons.admin_panel_settings_rounded,
                  size: 40,
                  color: isOwner ? Colors.amber.shade700 : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isOwner ? l10n.ownerFullAccess : _roleDisplayName(role, l10n),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (regionName != null && regionName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.location_on_rounded, size: 16),
                label: Text(regionName),
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeMode themeMode,
    Locale locale,
  ) {
    return _SectionCard(
      title: l10n.appearance,
      children: [
        ListTile(
          leading: _IconTile(
            icon: themeMode == ThemeMode.dark
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            color: AppColors.brandViolet,
          ),
          title: Text(l10n.theme),
          trailing: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded, size: 18),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selected) {
              ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
        ListTile(
          leading: const _IconTile(
            icon: Icons.language_rounded,
            color: AppColors.brandPurple,
          ),
          title: Text(l10n.language),
          subtitle: Text(
            locale.languageCode == 'ar'
                ? l10n.arabicLanguageName
                : l10n.englishLanguageName,
          ),
          trailing: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'en',
                label: Text(l10n.englishAbbreviation),
              ),
              ButtonSegment(
                value: 'ar',
                label: Text(l10n.arabicAbbreviation),
              ),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (selected) {
              ref
                  .read(adminLocaleProvider.notifier)
                  .setAdminLocale(Locale(selected.first));
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdministrationSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return _SectionCard(
      title: l10n.adminAdministrationSection,
      children: [
        _SectionTile(
          icon: Icons.storefront_rounded,
          color: AppColors.brandPurple,
          title: l10n.adminMerchants,
          onTap: () => context.go('/admin/merchants'),
        ),
        _SectionTile(
          icon: Icons.rate_review_rounded,
          color: AppColors.brandViolet,
          title: l10n.adminReviewsModeration,
          onTap: () => context.go('/admin/reviews-moderation'),
        ),
        _SectionTile(
          icon: Icons.receipt_long_rounded,
          color: AppColors.infoLight,
          title: l10n.adminOrdersPage,
          onTap: () => context.go('/admin/orders'),
        ),
        _SectionTile(
          icon: Icons.local_shipping_rounded,
          color: AppColors.orderReady,
          title: l10n.adminDrivers,
          onTap: () => context.go('/admin/drivers'),
        ),
        _SectionTile(
          icon: Icons.group_rounded,
          color: AppColors.warningLight,
          title: l10n.adminMembersSection,
          onTap: () => context.go('/admin/members'),
        ),
        _SectionTile(
          icon: Icons.support_agent_rounded,
          color: AppColors.successLight,
          title: l10n.support,
          onTap: () => context.go('/admin/support-chat'),
        ),
        _SectionTile(
          icon: Icons.verified_user_rounded,
          color: AppColors.brandPurple,
          title: l10n.chatPermissions,
          subtitle: l10n.chatPermissionsAdminSubtitle,
          onTap: () => context.go('/admin/chat-permissions'),
        ),
      ],
    );
  }

  Widget _buildPlatformSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return _SectionCard(
      title: l10n.adminPlatformSection,
      children: [
        _SectionTile(
          icon: Icons.account_balance_rounded,
          color: AppColors.brandPurple,
          title: l10n.adminFinancialCenter,
          onTap: () => context.go('/admin/financial-center'),
        ),
        _SectionTile(
          icon: Icons.menu_book_rounded,
          color: AppColors.brandViolet,
          title: l10n.adminTransactionLedger,
          onTap: () => context.go('/admin/transaction-ledger'),
        ),
        _SectionTile(
          icon: Icons.campaign_rounded,
          color: AppColors.infoLight,
          title: l10n.adminPushNotifications,
          onTap: () => context.go('/admin/push-notifications'),
        ),
        _SectionTile(
          icon: Icons.bar_chart_rounded,
          color: AppColors.orderReady,
          title: l10n.adminAnalytics,
          onTap: () => context.go('/admin/analytics'),
        ),
        _SectionTile(
          icon: Icons.settings_rounded,
          color: AppColors.warningLight,
          title: l10n.adminPlatformConfig,
          onTap: () => context.go('/admin/platform-config'),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, AppLocalizations l10n) {
    final profile = _profile!;
    return _SectionCard(
      title: l10n.account,
      children: [
        _SectionTile(
          icon: Icons.person_rounded,
          color: AppColors.brandPurple,
          title: l10n.adminProfile,
          subtitle: profile['role'] as String? ?? 'admin',
          onTap: () => context.go('/admin/profile'),
        ),
        _SectionTile(
          icon: Icons.info_outline_rounded,
          color: AppColors.brandViolet,
          title: l10n.about,
          subtitle: l10n.version,
          onTap: () => _showAboutDialog(context, l10n),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 240),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout_rounded),
          label: Text(
            AppLocalizations.of(context).logout,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            ),
            side: BorderSide(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
            ),
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.confirmLogout),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(authStateProvider.notifier).signOut();
    }
  }

  Future<void> _showAboutDialog(BuildContext context, AppLocalizations l10n) async {
    final isOwner = _profile!['is_owner'] as bool? ?? false;
    const flavor = AppFlavor.admin;
    var needsUpdate = false;
    OtaCheckResult? checkResult;
    try {
      final pkg = await PackageInfo.fromPlatform();
      final m = await fetchOtaManifest();
      final channel = m?.forFlavor(flavor);
      final current = int.tryParse(pkg.buildNumber) ?? 0;
      final latest = channel?.version ?? current;
      checkResult = OtaCheckResult(
        current: current,
        latest: latest,
        needsUpdate: latest > current,
      );
      needsUpdate = checkResult.needsUpdate;
    } catch (_) {
      needsUpdate = false;
    }
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: l10n.version,
      applicationIcon: CircleAvatar(
        backgroundColor: isOwner ? Colors.amber : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          isOwner ? Icons.star_rounded : Icons.admin_panel_settings_rounded,
          color: isOwner ? Colors.amber.shade800 : Theme.of(context).colorScheme.primary,
        ),
      ),
      children: [
        Text(
          l10n.adminSettingsMenu,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            await showUpdateAvailableAndDownload(
              context: context,
              flavor: flavor,
              result: checkResult!,
            );
          },
          icon: const Icon(Icons.system_update_alt_rounded),
          label: Text(
            needsUpdate ? l10n.updateAvailableNow : l10n.checkForUpdate,
          ),
        ),
      ],
    );
  }

  String _roleDisplayName(String role, AppLocalizations l10n) => switch (role) {
    'country_admin' => l10n.countryAdmin,
    'governorate_admin' => l10n.governorateAdmin,
    'center_admin' => l10n.centerAdmin,
    'village_admin' => l10n.villageAdmin,
    _ => l10n.adminRole,
  };
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _IconTile(icon: icon, color: color),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded, size: 22),
      onTap: onTap,
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}