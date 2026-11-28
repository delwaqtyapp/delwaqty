import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/profile/presentation/app_invitations_provider.dart';
import 'package:delwaqty/features/customer/profile/presentation/pages/edit_profile_page.dart';
import 'package:delwaqty/features/customer/profile/presentation/widgets/profile_sections.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/appearance_segmented.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';

/// Settings: account, app (theme, language, notifications) and support.
/// Theme and language moved here from the profile screen.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _version = info.version);
        })
        .catchError((_) {
          // Keep the l10n fallback label when package info is unavailable.
        });
  }

  Future<void> _editProfile(User user) async {
    final l10n = AppLocalizations.of(context);
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
    );
    if (saved == true && mounted) {
      context.showAppSnackBar(l10n.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colorScheme;
    final primary = cs.primary;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final authState = ref.watch(authStateProvider);
    final authUser = authState is AuthAuthenticated ? authState.user : null;
    final user = authUser == null
        ? null
        : (ref.watch(watchProfileUseCaseProvider(authUser.id)).value ??
              authUser);
    final hasInvitations =
        ref.watch(appFlavorProvider) == AppFlavor.customer &&
        (ref.watch(appInvitationsProvider).value?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ProfileSectionCard(
              title: l10n.account,
              children: [
                if (user != null)
                  ProfileSectionTile(
                    icon: Icons.person_outline_rounded,
                    color: primary,
                    title: l10n.editProfile,
                    onTap: () => _editProfile(user),
                  ),
                ProfileSectionTile(
                  icon: Icons.lock_outline_rounded,
                  color: primary,
                  title: l10n.privacySecurity,
                  onTap: () => context.push('/settings/privacy-security'),
                ),
                ProfileSectionTile(
                  icon: Icons.manage_accounts_outlined,
                  color: primary,
                  title: l10n.dataPrivacy,
                  onTap: () => context.push('/settings/data-privacy'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ProfileSectionCard(
              title: l10n.appSection,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ProfileIconTile(
                            icon: Icons.palette_outlined,
                            color: primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.theme,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppearanceSegmented<ThemeMode>(
                        options: [
                          AppearanceSegmentOption(
                            ThemeMode.light,
                            Icons.light_mode_rounded,
                            l10n.lightMode,
                          ),
                          AppearanceSegmentOption(
                            ThemeMode.dark,
                            Icons.dark_mode_rounded,
                            l10n.darkMode,
                          ),
                          AppearanceSegmentOption(
                            ThemeMode.system,
                            Icons.brightness_auto_rounded,
                            l10n.systemMode,
                          ),
                        ],
                        selected: themeMode,
                        onChanged: ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode,
                      ),
                    ],
                  ),
                ),
                ProfileSectionTile(
                  icon: Icons.language_rounded,
                  color: primary,
                  title: l10n.language,
                  subtitle: locale.languageCode == 'ar'
                      ? l10n.arabicLanguageName
                      : l10n.englishLanguageName,
                  onTap: () => context.push('/settings/language'),
                ),
                ProfileSectionTile(
                  icon: Icons.notifications_outlined,
                  color: primary,
                  title: l10n.notificationPreferences,
                  onTap: () =>
                      context.push('/settings/notification-preferences'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ProfileSectionCard(
              title: l10n.support,
              children: [
                if (hasInvitations)
                  ProfileSectionTile(
                    icon: Icons.mark_email_read_outlined,
                    color: primary,
                    title: l10n.appInvitationsTitle,
                    subtitle: l10n.appInvitationApproved,
                    onTap: () => context.push('/profile/app-invitations'),
                  ),
                ProfileSectionTile(
                  icon: Icons.lightbulb_outline_rounded,
                  color: primary,
                  title: l10n.suggestions,
                  subtitle: l10n.suggestionsProfileSubtitle,
                  onTap: () => context.push('/my-suggestions'),
                ),
                ProfileSectionTile(
                  icon: Icons.help_outline_rounded,
                  color: primary,
                  title: l10n.helpCenter,
                  onTap: () => context.push('/settings/help-center'),
                ),
                ProfileSectionTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: primary,
                  title: l10n.contactUs,
                  onTap: () => context.push('/support'),
                ),
                ProfileSectionTile(
                  icon: Icons.info_outline_rounded,
                  color: primary,
                  title: l10n.about,
                  subtitle: _version.isEmpty
                      ? l10n.version
                      : '${l10n.version.split(' ').first} $_version',
                  onTap: () => context.push('/settings/about'),
                ),
                ProfileSectionTile(
                  icon: Icons.description_outlined,
                  color: primary,
                  title: l10n.termsOfService,
                  onTap: () => context.push('/settings/terms-of-service'),
                ),
                ProfileSectionTile(
                  icon: Icons.privacy_tip_outlined,
                  color: primary,
                  title: l10n.privacyPolicy,
                  onTap: () => context.push('/settings/privacy-policy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
