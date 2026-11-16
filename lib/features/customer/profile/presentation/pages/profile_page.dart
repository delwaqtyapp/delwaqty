import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';
import 'package:delwaqty/shared/widgets/appearance_segmented.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/floating_glass_buttons.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isUploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isGuest = authState is AuthGuest;

    if (isGuest) {
      return _buildGuestProfile(context, l10n);
    }

    final isProvider = ref.watch(appFlavorProvider) == AppFlavor.provider;

    return Scaffold(
      body: GradientBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildHeroSliverAppBar(context, authState, l10n),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                kFloatingNavClearance + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  AnimatedFadeIn(
                    child: _buildBentoQuickActions(context, isProvider, l10n),
                  ),
                  const SizedBox(height: 18),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 70),
                    child: _buildAccountSection(context, isProvider, l10n),
                  ),
                  const SizedBox(height: 18),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 120),
                    child: _buildAppearanceSection(
                      context,
                      l10n,
                      themeMode,
                      locale,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 170),
                    child: _buildSupportAndLegalSection(context, l10n),
                  ),
                  const SizedBox(height: 24),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 220),
                    child: _buildLogoutButton(context, l10n),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSliverAppBar(
    BuildContext context,
    AuthState authState,
    AppLocalizations l10n,
  ) {
    final authUser = authState is AuthAuthenticated ? authState.user : null;
    final userId = authUser?.id;
    final profileAsync = userId != null
        ? ref.watch(watchProfileUseCaseProvider(userId))
        : null;
    final user = profileAsync?.value ?? authUser;

    final topPadding = MediaQuery.paddingOf(context).top;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 280,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: context.colorScheme.surface.withValues(alpha: 0.88),
      automaticallyImplyLeading: false,
      leadingWidth: 64,
      leading: const Padding(
        padding: EdgeInsetsDirectional.only(start: 14),
        child: Center(
          child: FloatingMenuCircleButton(size: 40, overDarkHero: true),
        ),
      ),
      actions: const [
        Padding(
          padding: EdgeInsetsDirectional.only(end: 14),
          child: Center(
            child: FloatingNotificationCircleButton(
              size: 40,
              overDarkHero: true,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      AppColors.brandPurpleDeep,
                      AppColors.brandPurple,
                      AppColors.brandViolet,
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                top: -40,
                end: -30,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandCyan.withValues(alpha: 0.16),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -50,
                start: -40,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding + 52, 16, 16),
                child: user == null
                    ? const SizedBox.shrink()
                    : _buildGlassHeroCard(context, user, l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassHeroCard(
    BuildContext context,
    User user,
    AppLocalizations l10n,
  ) {
    final initial = (user.fullName?.isNotEmpty ?? false)
        ? user.fullName![0].toUpperCase()
        : (user.username?.isNotEmpty ?? false)
        ? user.username![0].toUpperCase()
        : 'U';
    final roleLabel = _roleLabel(user.role, l10n);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width - 68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _GradientAvatarRing(
                        child: ClipOval(
                          child: SizedBox(
                            width: 82,
                            height: 82,
                            child: user.avatarUrl?.isNotEmpty == true
                                ? Image.network(
                                    user.avatarUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                        alignment: Alignment.center,
                                        child: const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, _, _) =>
                                        _buildAvatarFallback(context, initial),
                                  )
                                : _buildAvatarFallback(context, initial),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: -2,
                        end: -2,
                        child: GestureDetector(
                          onTap: _isUploadingAvatar
                              ? null
                              : () => _onChangePhoto(context, user.id, l10n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: AlignmentDirectional.topStart,
                                end: AlignmentDirectional.bottomEnd,
                                colors: [
                                  AppColors.brandPurple,
                                  AppColors.brandViolet,
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x3D5B3DF0),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _isUploadingAvatar
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          user.fullName ?? user.username ?? l10n.user,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (user.verificationStatus.isApproved) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ],
                  ),
                  if (user.username?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (roleLabel != null) _RoleChip(label: roleLabel),
                      FilledButton.icon(
                        onPressed: () =>
                            _showEditProfileSheet(context, user, l10n),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppSpacing.borderRadiusFull,
                            side: BorderSide(color: Colors.white38),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: Text(
                          l10n.editProfile,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBentoQuickActions(
    BuildContext context,
    bool isProvider,
    AppLocalizations l10n,
  ) {
    final items = isProvider
        ? [
            _BentoActionItem(
              icon: Icons.account_balance_wallet_rounded,
              label: l10n.financialCenter,
              accent: const Color(0xFF10B981),
              onTap: () => context.push('/provider-financial-center'),
            ),
            _BentoActionItem(
              icon: Icons.receipt_long_rounded,
              label: l10n.viewOrders,
              accent: AppColors.brandPurple,
              onTap: () => context.push('/merchant-dashboard/orders'),
            ),
            _BentoActionItem(
              icon: Icons.storefront_rounded,
              label: l10n.storefront,
              accent: AppColors.brandBlue,
              onTap: () => context.push('/merchant-dashboard/storefront'),
            ),
          ]
        : [
            _BentoActionItem(
              icon: Icons.account_balance_wallet_rounded,
              label: l10n.wallet,
              accent: const Color(0xFF10B981),
              onTap: () => context.push('/wallet'),
            ),
            _BentoActionItem(
              icon: Icons.stars_rounded,
              label: l10n.rewards,
              accent: AppColors.brandGold,
              onTap: () => context.push('/rewards'),
            ),
            _BentoActionItem(
              icon: Icons.receipt_long_rounded,
              label: l10n.previousOrders,
              accent: AppColors.brandPurple,
              onTap: () => context.push('/market/orders'),
            ),
          ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _BentoActionTile(item: items[i])),
        ],
      ],
    );
  }

  Widget _buildGuestProfile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        leading: const Padding(
          padding: EdgeInsetsDirectional.only(start: 12),
          child: Center(child: FloatingMenuCircleButton(size: 40)),
        ),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 12),
            child: Center(child: FloatingNotificationCircleButton(size: 40)),
          ),
        ],
      ),
      body: GradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              kFloatingNavClearance + MediaQuery.paddingOf(context).bottom,
            ),
            child: PremiumCard(
              padding: const EdgeInsets.all(28),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  AppColors.brandPurple.withValues(alpha: 0.14),
                  context.colorScheme.surfaceContainerLowest,
                ],
              ),
              borderColor: AppColors.brandPurple.withValues(alpha: 0.2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _GuestAvatar(),
                  const SizedBox(height: 24),
                  Text(
                    l10n.guestMode,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.guestModeHint,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.pushNamed('login'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusButton,
                          ),
                        ),
                      ),
                      child: Text(l10n.login),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.pushNamed('register'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusButton,
                          ),
                        ),
                      ),
                      child: Text(l10n.register),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _roleLabel(String role, AppLocalizations l10n) {
    switch (role) {
      case 'admin':
        return l10n.admin;
      case 'driver':
        return l10n.driver;
      case 'merchant':
        return l10n.merchant;
      case 'provider':
        return l10n.provider;
      case 'owner':
        return l10n.owner;
      default:
        return null;
    }
  }

  Widget _buildAvatarFallback(BuildContext context, String initial) {
    return Container(
      color: context.colorScheme.primary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: context.textTheme.headlineMedium?.copyWith(
          color: context.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _onChangePhoto(
    BuildContext context,
    String userId,
    AppLocalizations l10n,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusSheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.outlineVariant,
                borderRadius: AppSpacing.borderRadiusFull,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (file == null || !context.mounted) return;

      setState(() => _isUploadingAvatar = true);
      final bytes = await file.readAsBytes();
      final url = await ref
          .read(uploadAvatarUseCaseProvider)
          .call(
            userId: userId,
            bytes: bytes,
            fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
      if (!context.mounted) return;
      await ref
          .read(updateProfileUseCaseProvider)
          .call(userId: userId, data: {'avatar_url': url});
      if (context.mounted) {
        context.showAppSnackBar(l10n.success);
      }
    } catch (e) {
      if (context.mounted) {
        context.showAppSnackBar(appErrorText(context, e));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    User user,
    AppLocalizations l10n,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditProfileSheet(
        user: user,
        l10n: l10n,
      ),
    );

    if (saved == true && context.mounted) {
      context.showAppSnackBar(l10n.success);
    }
  }

  Widget _buildAccountSection(
    BuildContext context,
    bool isProvider,
    AppLocalizations l10n,
  ) {
    return _SectionCard(
      title: l10n.account,
      children: [
        _SectionTile(
          icon: Icons.lock_outline_rounded,
          color: AppColors.warningLight,
          title: l10n.privacySecurity,
          onTap: () => context.push('/settings/privacy-security'),
        ),
        if (isProvider)
          _SectionTile(
            icon: Icons.schedule_rounded,
            color: AppColors.brandViolet,
            title: l10n.availability,
            onTap: () => context.push('/provider-availability'),
          ),
        _SectionTile(
          icon: Icons.notifications_outlined,
          color: AppColors.infoLight,
          title: l10n.notifications,
          onTap: () => context.push('/notifications'),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeMode themeMode,
    Locale locale,
  ) {
    final themeLabel = switch (themeMode) {
      ThemeMode.light => l10n.lightMode,
      ThemeMode.dark => l10n.darkMode,
      ThemeMode.system => l10n.systemMode,
    };
    final themeIcon = switch (themeMode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };
    return _SectionCard(
      title: l10n.appearance,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconTile(icon: themeIcon, color: AppColors.brandViolet),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.theme,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        themeLabel,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                onChanged: ref.read(themeModeProvider.notifier).setThemeMode,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _IconTile(
                    icon: Icons.language_rounded,
                    color: AppColors.brandPurple,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.language,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locale.languageCode == 'ar'
                            ? l10n.arabicLanguageName
                            : l10n.englishLanguageName,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppearanceSegmented<String>(
                options: [
                  AppearanceSegmentOption(
                    'en',
                    Icons.translate_rounded,
                    l10n.englishLanguageName,
                  ),
                  AppearanceSegmentOption(
                    'ar',
                    Icons.language_rounded,
                    l10n.arabicLanguageName,
                  ),
                ],
                selected: locale.languageCode,
                onChanged: (code) =>
                    ref.read(localeProvider.notifier).setLocale(Locale(code)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportAndLegalSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return _SectionCard(
      title: l10n.support,
      children: [
        _SectionTile(
          icon: Icons.help_outline_rounded,
          color: AppColors.infoLight,
          title: l10n.helpCenter,
          onTap: () => context.push('/settings/help-center'),
        ),
        _SectionTile(
          icon: Icons.support_agent_rounded,
          color: AppColors.brandPurple,
          title: l10n.support,
          onTap: () => context.push('/support'),
        ),
        _SectionTile(
          icon: Icons.info_outline_rounded,
          color: AppColors.brandViolet,
          title: l10n.about,
          subtitle: l10n.version,
          onTap: () => context.push('/settings/about'),
        ),
        _SectionTile(
          icon: Icons.description_outlined,
          color: AppColors.successLight,
          title: l10n.termsOfService,
          onTap: () => context.push('/settings/terms-of-service'),
        ),
        _SectionTile(
          icon: Icons.privacy_tip_outlined,
          color: AppColors.warningLight,
          title: l10n.privacyPolicy,
          onTap: () => context.push('/settings/privacy-policy'),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return OutlinedButton.icon(
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusDialog),
            ),
            title: Text(l10n.logout),
            content: Text(l10n.areYouSureYouWantToLogout),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  ref.read(authStateProvider.notifier).signOut();
                },
                child: Text(
                  l10n.logout,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            ],
          ),
        );
      },
      icon: Icon(Icons.logout_rounded, color: context.colorScheme.error),
      label: Text(
        l10n.logout,
        style: TextStyle(color: context.colorScheme.error),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: context.colorScheme.error.withValues(alpha: 0.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        ),
      ),
    );
  }
}

class _BentoActionItem {
  const _BentoActionItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
}

class _BentoActionTile extends StatelessWidget {
  const _BentoActionTile({required this.item});

  final _BentoActionItem item;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: item.onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      radius: 20,
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          item.accent.withValues(alpha: 0.14),
          context.colorScheme.surfaceContainerLowest,
        ],
      ),
      borderColor: item.accent.withValues(alpha: 0.22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  item.accent.withValues(alpha: 0.25),
                  item.accent.withValues(alpha: 0.10),
                ],
              ),
            ),
            child: Icon(item.icon, size: 22, color: item.accent),
          ),
          const SizedBox(height: 10),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user, required this.l10n});

  final User user;
  final AppLocalizations l10n;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;
  DateTime? _selectedDate;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user.fullName ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.user.username ?? '',
    );
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _selectedDate = widget.user.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();

    final data = <String, dynamic>{};
    if (name.isNotEmpty) {
      data['full_name'] = name;
    }
    data['username'] = username.isEmpty ? null : username;
    data['phone'] = phone.isEmpty ? null : phone;

    try {
      if (data.isNotEmpty) {
        await ref
            .read(updateProfileUseCaseProvider)
            .call(userId: widget.user.id, data: data);
      }
      final dobChanged = _selectedDate != widget.user.dateOfBirth;
      if (dobChanged) {
        await ref.read(updateDateOfBirthUseCaseProvider).call(
              userId: widget.user.id,
              dateOfBirth: _selectedDate,
            );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = appErrorText(context, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorScheme.outlineVariant,
                  borderRadius: AppSpacing.borderRadiusFull,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.editProfile,
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.cancel,
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colorScheme.errorContainer.withValues(
                    alpha: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              enabled: !_saving,
              decoration: InputDecoration(labelText: l10n.fullName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: l10n.username,
                prefixText: '@',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              enabled: !_saving,
              decoration: InputDecoration(labelText: l10n.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        helpText: l10n.dateOfBirth,
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                        });
                      }
                    },
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.dateOfBirth),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? l10n.notSet
                            : _formatDate(_selectedDate!),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.dateOfBirthPrivacy,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _selectedDate = null),
                icon: const Icon(Icons.clear, size: 16),
                label: Text(l10n.clear),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusButton,
                        ),
                      ),
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusButton,
                        ),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.saveChanges),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
          child: Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: context.colorScheme.surfaceContainerLowest.withValues(
            alpha: 0.92,
          ),
          borderColor: context.colorScheme.outlineVariant.withValues(
            alpha: 0.18,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: List.generate(children.length, (index) {
                final tile = children[index];
                return Column(
                  children: [
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          height: 1,
                          color: context.colorScheme.outlineVariant.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                    tile,
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _IconTile(icon: icon, color: color),
      title: Text(
        title,
        style: context.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: context.textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded),
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
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [AppColors.brandPurple, AppColors.brandViolet],
        ),
        borderRadius: AppSpacing.borderRadiusFull,
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GradientAvatarRing extends StatelessWidget {
  const _GradientAvatarRing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [AppColors.brandPurple, AppColors.brandViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x3D5B3DF0),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GuestAvatar extends StatelessWidget {
  const _GuestAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            AppColors.brandPurple.withValues(alpha: 0.25),
            AppColors.brandViolet.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: AppColors.brandPurple.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPurple.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: 60,
        color: AppColors.brandPurple.withValues(alpha: 0.75),
      ),
    );
  }
}
