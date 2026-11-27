import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/profile/presentation/app_invitations_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';
import 'package:delwaqty/shared/widgets/appearance_segmented.dart';
import 'package:delwaqty/shared/widgets/adaptive_tile_wrap.dart';
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
  String _appVersionLabel = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => _appVersionLabel = info.version);
          }
        })
        .catchError((_) {
          // Keep the l10n fallback label when package info is unavailable.
        });
  }

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

    final flavor = ref.watch(appFlavorProvider);
    final isProvider = flavor == AppFlavor.provider;
    final isDriver = flavor == AppFlavor.driver;

    return Scaffold(
      body: GradientBackground(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(
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
                    child: _buildBentoQuickActions(
                      context,
                      isProvider,
                      isDriver,
                      l10n,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 70),
                    child: _buildAccountSection(
                      context,
                      isProvider,
                      isDriver,
                      l10n,
                    ),
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
                  const SizedBox(height: 22),
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
      expandedHeight: 256,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
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
        background: ClipPath(
          clipper: const _ProfileHeroWaveClipper(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      Color(0xFF170B3B),
                      AppColors.brandPurpleDeep,
                      AppColors.brandPurple,
                      Color(0xFF4C1D95),
                    ],
                  ),
                ),
              ),
              Image.asset(
                'assets/egypt/profile_hero_bg.webp',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.16),
                      Colors.black.withValues(alpha: 0.36),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding + 54, 16, 26),
                child: user == null
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: _buildGlassHeroCard(context, user, l10n),
                      ),
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
    final contactInfo = (user.phone?.isNotEmpty ?? false)
        ? user.phone!
        : (user.email.isNotEmpty ? user.email : null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _GradientAvatarRing(
                    child: ClipOval(
                      child: SizedBox(
                        width: 74,
                        height: 74,
                        child: user.avatarUrl?.isNotEmpty == true
                            ? Image.network(
                                user.avatarUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                        alignment: Alignment.center,
                                        child: const SizedBox(
                                          width: 20,
                                          height: 20,
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
                        padding: const EdgeInsets.all(6),
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
                          border: Border.all(color: Colors.white, width: 1.8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x45170B3B),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _isUploadingAvatar
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName ?? user.username ?? l10n.user,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.verificationStatus.isApproved) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: AppColors.brandGold,
                          ),
                        ],
                      ],
                    ),
                    if (user.username?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else if (contactInfo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        contactInfo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (roleLabel != null) _RoleChip(label: roleLabel),
                        FilledButton.icon(
                          onPressed: () =>
                              _showEditProfileSheet(context, user, l10n),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppSpacing.borderRadiusFull,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.32),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: Text(
                            l10n.editProfile,
                            style: context.textTheme.labelSmall?.copyWith(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoQuickActions(
    BuildContext context,
    bool isProvider,
    bool isDriver,
    AppLocalizations l10n,
  ) {
    final items = isDriver
        ? [
            _BentoActionItem(
              icon: Icons.account_balance_wallet_rounded,
              label: l10n.financialCenter,
              accent: AppColors.brandPurple,
              onTap: () => context.push('/driver/financial-center'),
            ),
            _BentoActionItem(
              icon: Icons.two_wheeler_rounded,
              label: l10n.vehicleManagement,
              accent: AppColors.brandViolet,
              onTap: () => context.push('/driver/vehicles'),
            ),
          ]
        : isProvider
        ? [
            _BentoActionItem(
              icon: Icons.account_balance_wallet_rounded,
              label: l10n.financialCenter,
              accent: AppColors.brandPurple,
              onTap: () => context.push('/provider-financial-center'),
            ),
            _BentoActionItem(
              icon: Icons.receipt_long_rounded,
              label: l10n.viewOrders,
              accent: AppColors.brandViolet,
              onTap: () => context.push('/merchant-dashboard/orders'),
            ),
            _BentoActionItem(
              icon: Icons.storefront_rounded,
              label: l10n.storefront,
              accent: AppColors.brandGold,
              onTap: () => context.push('/merchant-dashboard/storefront'),
            ),
          ]
        : [
            _BentoActionItem(
              icon: Icons.account_balance_wallet_rounded,
              label: l10n.wallet,
              accent: AppColors.brandPurple,
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
              accent: AppColors.brandViolet,
              onTap: () => context.push('/market/orders'),
            ),
            _BentoActionItem(
              icon: Icons.event_seat_rounded,
              label: l10n.myReservations,
              accent: AppColors.brandPurple,
              onTap: () => context.push('/my-reservations'),
            ),
          ];

    // AdaptiveTileWrap: column count adapts to width AND text scale, and a
    // short last row stretches to full width instead of dangling an orphan
    // tile (owner feedback at large system font sizes).
    return AdaptiveTileWrap(
      children: [for (final item in items) _BentoActionTile(item: item)],
    );
  }

  Widget _buildGuestProfile(BuildContext context, AppLocalizations l10n) {
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
      useRootNavigator: true,
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
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditProfileSheet(user: user, l10n: l10n),
    );

    if (saved == true && context.mounted) {
      context.showAppSnackBar(l10n.success);
    }
  }

  Widget _buildAccountSection(
    BuildContext context,
    bool isProvider,
    bool isDriver,
    AppLocalizations l10n,
  ) {
    final primary = context.colorScheme.primary;
    return _SectionCard(
      title: l10n.account,
      children: [
        _SectionTile(
          icon: Icons.lock_outline_rounded,
          color: primary,
          title: l10n.privacySecurity,
          onTap: () => context.push('/settings/privacy-security'),
        ),
        if (!isProvider && !isDriver)
          _SectionTile(
            icon: Icons.favorite_border_rounded,
            color: primary,
            title: l10n.favorites,
            onTap: () => context.push('/market/favorites'),
          ),
        if (!isProvider && !isDriver)
          _SectionTile(
            icon: Icons.event_note_outlined,
            color: primary,
            title: l10n.myBookings,
            onTap: () => context.push('/home-services/my-bookings'),
          ),
        if (!isProvider && !isDriver)
          _SectionTile(
            icon: Icons.notifications_outlined,
            color: primary,
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
    final cs = context.colorScheme;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconTile(icon: themeIcon, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.theme,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          themeLabel,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
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
                onChanged: ref.read(themeModeProvider.notifier).setThemeMode,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconTile(icon: Icons.language_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.language,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locale.languageCode == 'ar'
                              ? l10n.arabicLanguageName
                              : l10n.englishLanguageName,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
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
    final primary = context.colorScheme.primary;
    final hasInvitations =
        ref.watch(appFlavorProvider) == AppFlavor.customer &&
        (ref.watch(appInvitationsProvider).value?.isNotEmpty ?? false);
    return _SectionCard(
      title: l10n.support,
      children: [
        if (hasInvitations)
          _SectionTile(
            icon: Icons.mark_email_read_outlined,
            color: primary,
            title: l10n.appInvitationsTitle,
            subtitle: l10n.appInvitationApproved,
            onTap: () => context.push('/profile/app-invitations'),
          ),
        // Suggestions entry in the profile screen (owner request
        // 2026-11-23, all four apps; complaints lives in the side menu).
        _SectionTile(
          icon: Icons.lightbulb_outline_rounded,
          color: primary,
          title: l10n.suggestions,
          subtitle: l10n.suggestionsProfileSubtitle,
          onTap: () => context.push('/my-suggestions'),
        ),
        _SectionTile(
          icon: Icons.help_outline_rounded,
          color: primary,
          title: l10n.helpCenter,
          onTap: () => context.push('/settings/help-center'),
        ),
        _SectionTile(
          icon: Icons.support_agent_rounded,
          color: primary,
          title: l10n.support,
          onTap: () => context.push('/support'),
        ),
        _SectionTile(
          icon: Icons.info_outline_rounded,
          color: primary,
          title: l10n.about,
          subtitle: _appVersionLabel.isEmpty
              ? l10n.version
              : '${l10n.version.split(' ').first} $_appVersionLabel',
          onTap: () => context.push('/settings/about'),
        ),
        _SectionTile(
          icon: Icons.description_outlined,
          color: primary,
          title: l10n.termsOfService,
          onTap: () => context.push('/settings/terms-of-service'),
        ),
        _SectionTile(
          icon: Icons.privacy_tip_outlined,
          color: primary,
          title: l10n.privacyPolicy,
          onTap: () => context.push('/settings/privacy-policy'),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, AppLocalizations l10n) {
    final errorColor = context.colorScheme.error;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
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
                  child: Text(l10n.logout, style: TextStyle(color: errorColor)),
                ),
              ],
            ),
          );
        },
        icon: Icon(Icons.logout_rounded, size: 20, color: errorColor),
        label: Text(
          l10n.logout,
          style: context.textTheme.labelLarge?.copyWith(
            color: errorColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: errorColor.withValues(alpha: 0.06),
          side: BorderSide(
            color: errorColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
      radius: 18,
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          item.accent.withValues(alpha: 0.12),
          context.colorScheme.surfaceContainerLowest,
        ],
      ),
      borderColor: item.accent.withValues(alpha: 0.22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  item.accent.withValues(alpha: 0.20),
                  item.accent.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(color: item.accent.withValues(alpha: 0.22)),
            ),
            child: Icon(item.icon, size: 21, color: item.accent),
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
    _nameController = TextEditingController(text: widget.user.fullName ?? '');
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

    if (username.isNotEmpty && !AppValidators.isValidUsername(username)) {
      setState(() {
        _saving = false;
        _errorMessage = widget.l10n.usernameInvalid;
      });
      return;
    }

    final data = <String, dynamic>{};
    if (name.isNotEmpty) {
      data['full_name'] = name;
    }
    data['username'] = username.isEmpty ? null : username;

    try {
      if (data.isNotEmpty) {
        await ref
            .read(updateProfileUseCaseProvider)
            .call(userId: widget.user.id, data: data);
      }
      final dobChanged = _selectedDate != widget.user.dateOfBirth;
      if (dobChanged) {
        await ref
            .read(updateDateOfBirthUseCaseProvider)
            .call(userId: widget.user.id, dateOfBirth: _selectedDate);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = e.toString().contains('users_username_unique_idx')
              ? widget.l10n.usernameTaken
              : appErrorText(context, e);
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
              readOnly: true,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: l10n.phone,
                helperText: l10n.phoneChangeUnavailable,
                helperMaxLines: 3,
              ),
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
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.brandPurple, AppColors.brandViolet],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
        ),
        PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          radius: 20,
          color: cs.surfaceContainerLowest.withValues(alpha: 0.94),
          borderColor: cs.outlineVariant.withValues(alpha: 0.22),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: List.generate(children.length, (index) {
                final tile = children[index];
                return Column(
                  children: [
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Divider(
                          height: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.25),
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
    final cs = context.colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      minVerticalPadding: 10,
      leading: _IconTile(icon: icon, color: color),
      title: Text(
        title,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: context.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
      ),
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
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.20),
        borderRadius: AppSpacing.borderRadiusFull,
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: 13,
            color: AppColors.brandGold,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            AppColors.brandGold,
            AppColors.brandViolet,
            AppColors.brandPurple,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x42170B3B),
            blurRadius: 16,
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

class _ProfileHeroWaveClipper extends CustomClipper<Path> {
  const _ProfileHeroWaveClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()..lineTo(0, h - 18);

    path.quadraticBezierTo(w * 0.12, h, w * 0.28, h - 10);
    path.quadraticBezierTo(w * 0.44, h - 22, w * 0.60, h - 8);
    path.quadraticBezierTo(w * 0.76, h + 2, w * 0.90, h - 14);
    path.quadraticBezierTo(w * 0.96, h - 21, w, h - 16);

    path
      ..lineTo(w, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
