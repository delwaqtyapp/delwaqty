import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/profile/presentation/pages/edit_profile_page.dart';
import 'package:delwaqty/features/customer/profile/presentation/widgets/avatar_picker.dart';
import 'package:delwaqty/features/customer/profile/presentation/widgets/profile_sections.dart';
import 'package:delwaqty/gen/assets.gen.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final isGuest = authState is AuthGuest;

    if (isGuest) {
      return _buildGuestProfile(context, l10n);
    }

    final flavor = ref.watch(appFlavorProvider);
    final isProvider = flavor == AppFlavor.provider;
    final isDriver = flavor == AppFlavor.driver;

    final authUser = authState is AuthAuthenticated ? authState.user : null;
    final profileAsync = authUser != null
        ? ref.watch(watchProfileUseCaseProvider(authUser.id))
        : null;
    final user = profileAsync?.value ?? authUser;

    return Scaffold(
      body: GradientBackground(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: user == null
                  ? SizedBox(height: MediaQuery.paddingOf(context).top + 64)
                  : _buildHeader(context, user, l10n),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                kFloatingNavClearance + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  AnimatedFadeIn(
                    child: _buildQuickActions(
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
                  const SizedBox(height: 22),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 120),
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

  Future<void> _openEditProfile(BuildContext context, User user) async {
    final l10n = AppLocalizations.of(context);
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
    );
    if (saved == true && context.mounted) {
      context.showAppSnackBar(l10n.success);
    }
  }

  Widget _buildHeader(BuildContext context, User user, AppLocalizations l10n) {
    final cs = context.colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    final initial = (user.fullName?.isNotEmpty ?? false)
        ? user.fullName![0].toUpperCase()
        : (user.username?.isNotEmpty ?? false)
        ? user.username![0].toUpperCase()
        : 'U';
    final roleLabel = _roleLabel(user.role, l10n);
    final contact = (user.phone?.isNotEmpty ?? false)
        ? user.phone!
        : (user.email.isNotEmpty ? user.email : null);

    return SizedBox(
      height: top + 332,
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            height: 190,
            child: CustomPaint(
              painter: _SkylinePainter(
                color: cs.primary,
                dark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, top + 8, 14, 0),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const FloatingMenuCircleButton(size: 40),
                      const Spacer(),
                      Image.asset(
                        Assets.egypt.delwaqtyLogoMark.path,
                        width: 30,
                        height: 30,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.appName,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      const FloatingNotificationCircleButton(size: 40),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 240,
                  height: 128,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _AvatarRing(
                        child: GestureDetector(
                          onTap: () => _openEditProfile(context, user),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: cs.primary,
                            foregroundImage: user.avatarUrl?.isNotEmpty == true
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: Text(
                              initial,
                              style: context.textTheme.headlineMedium?.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: 4,
                        start: 44,
                        child: _RoundBadge(
                          icon: Icons.camera_alt_rounded,
                          busy: _isUploadingAvatar,
                          semantic: l10n.takePhoto,
                          onTap: _isUploadingAvatar
                              ? null
                              : () => pickAndUploadAvatar(
                                  context: context,
                                  ref: ref,
                                  userId: user.id,
                                  l10n: l10n,
                                  onBusy: (b) {
                                    if (mounted) {
                                      setState(() => _isUploadingAvatar = b);
                                    }
                                  },
                                ),
                        ),
                      ),
                      PositionedDirectional(
                        end: 0,
                        bottom: 22,
                        child: _RoundBadge(
                          icon: Icons.settings_rounded,
                          semantic: l10n.settings,
                          onTap: () => context.push('/settings'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openEditProfile(context, user),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          user.fullName ?? user.username ?? l10n.user,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (user.verificationStatus.isApproved) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 20,
                          color: AppColors.brandViolet,
                        ),
                      ],
                    ],
                  ),
                ),
                if (user.username?.isNotEmpty == true)
                  Text(
                    '@${user.username}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (contact != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (user.phone?.isNotEmpty ?? false)
                                  ? Icons.phone_rounded
                                  : Icons.mail_outline_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 6),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                contact,
                                style: context.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (roleLabel != null) _RoleChip(label: roleLabel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
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
            _BentoActionItem(
              icon: Icons.location_on_rounded,
              label: l10n.myAddresses,
              accent: AppColors.brandCyan,
              onTap: () => context.push('/profile/addresses'),
            ),
            _BentoActionItem(
              icon: Icons.support_agent_rounded,
              label: l10n.support,
              accent: AppColors.brandViolet,
              onTap: () => context.push('/support'),
            ),
          ];

    // AdaptiveTileWrap: column count adapts to width AND text scale, and a
    // short last row stretches to full width instead of dangling an orphan.
    return AdaptiveTileWrap(
      children: [for (final item in items) _BentoActionTile(item: item)],
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    bool isProvider,
    bool isDriver,
    AppLocalizations l10n,
  ) {
    final primary = context.colorScheme.primary;
    return ProfileSectionCard(
      children: [
        ProfileSectionTile(
          icon: Icons.lock_outline_rounded,
          color: primary,
          title: l10n.privacySecurity,
          onTap: () => context.push('/settings/privacy-security'),
        ),
        if (!isProvider && !isDriver)
          ProfileSectionTile(
            icon: Icons.favorite_border_rounded,
            color: primary,
            title: l10n.favorites,
            onTap: () => context.push('/market/favorites'),
          ),
        if (!isProvider && !isDriver)
          ProfileSectionTile(
            icon: Icons.event_note_outlined,
            color: primary,
            title: l10n.myBookings,
            onTap: () => context.push('/home-services/my-bookings'),
          ),
        if (!isProvider && !isDriver)
          ProfileSectionTile(
            icon: Icons.notifications_outlined,
            color: primary,
            title: l10n.notifications,
            onTap: () => context.push('/notifications'),
          ),
      ],
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
    final cs = context.colorScheme;
    // One neutral surface and one accent for every tile.
    return PremiumCard(
      onTap: item.onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      radius: 20,
      color: cs.surfaceContainerLowest,
      borderColor: cs.outlineVariant.withValues(alpha: 0.28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 28, color: cs.primary),
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

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colorScheme.surface,
        border: Border.all(
          color: context.colorScheme.primary.withValues(alpha: 0.55),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundBadge extends StatelessWidget {
  const _RoundBadge({
    required this.icon,
    required this.semantic,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String semantic;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Semantics(
      button: true,
      label: semantic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary,
            border: Border.all(color: cs.surface, width: 2.5),
          ),
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(9),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : Icon(icon, size: 18, color: cs.onPrimary),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandGold.withValues(alpha: 0.18),
        borderRadius: AppSpacing.borderRadiusFull,
        border: Border.all(color: AppColors.brandGold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: 14,
            color: AppColors.brandGold,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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

/// Light vector skyline (Cairo Tower, a dome and a minaret among blocks)
/// painted behind the header: no image asset, no blur, cheap on weak phones.
class _SkylinePainter extends CustomPainter {
  const _SkylinePainter({required this.color, required this.dark});

  final Color color;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final far = Paint()..color = color.withValues(alpha: dark ? 0.16 : 0.10);
    final near = Paint()..color = color.withValues(alpha: dark ? 0.24 : 0.16);

    // soft hills
    final hill = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.25, h * 0.55, w * 0.5, h * 0.7)
      ..quadraticBezierTo(w * 0.78, h * 0.86, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hill, far);

    // blocks (far)
    final blocks = <List<double>>[
      [0.02, 0.05, 0.40],
      [0.08, 0.06, 0.52],
      [0.15, 0.05, 0.36],
      [0.74, 0.06, 0.50],
      [0.81, 0.05, 0.38],
      [0.88, 0.07, 0.56],
      [0.95, 0.05, 0.34],
    ];
    for (final b in blocks) {
      final bh = h * b[2];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * b[0], h - bh, w * b[1], bh),
          const Radius.circular(3),
        ),
        near,
      );
    }

    // Cairo Tower (slim shaft + lotus top) on the end side
    final tx = w * 0.84;
    final shaftTop = h * 0.30;
    canvas.drawRect(Rect.fromLTRB(tx - 4, shaftTop, tx + 4, h), far);
    final lotus = Path()
      ..moveTo(tx - 12, shaftTop)
      ..quadraticBezierTo(tx - 16, shaftTop - 22, tx - 4, shaftTop - 30)
      ..lineTo(tx + 4, shaftTop - 30)
      ..quadraticBezierTo(tx + 16, shaftTop - 22, tx + 12, shaftTop)
      ..close();
    canvas.drawPath(lotus, far);
    canvas.drawRect(
      Rect.fromLTRB(tx - 1, shaftTop - 46, tx + 1, shaftTop - 30),
      far,
    );

    // dome + minaret on the start side
    final dx = w * 0.20;
    canvas.drawRect(Rect.fromLTWH(dx - 28, h * 0.62, 56, h * 0.38), far);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(dx, h * 0.62), width: 56, height: 44),
      3.14159,
      3.14159,
      true,
      far,
    );
    canvas.drawRect(Rect.fromLTWH(dx + 34, h * 0.40, 7, h * 0.60), far);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(dx + 37.5, h * 0.40),
        width: 12,
        height: 18,
      ),
      3.14159,
      3.14159,
      true,
      far,
    );
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter old) =>
      old.color != color || old.dark != dark;
}
