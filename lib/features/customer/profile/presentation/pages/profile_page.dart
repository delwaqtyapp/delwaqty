import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/auth/admin_access.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isGuest = authState is AuthGuest;

    if (isGuest) {
      return _buildGuestProfile(context, ref, l10n);
    }

    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;
    final isDriver =
        authState is AuthAuthenticated && authState.user.role == 'driver';
    final isMerchant =
        authState is AuthAuthenticated && authState.user.role == 'merchant';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnimatedFadeIn(
              child: _buildProfileHeader(context, ref, authState, l10n),
            ),
            const SizedBox(height: 16),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 100),
              child: _buildSettingsSection(context, ref, l10n, themeMode, locale),
            ),
            const SizedBox(height: 16),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 120),
              child: _buildOrdersAndInvoicesSection(context, l10n),
            ),
            if (isAdmin || isDriver || isMerchant) ...[
              const SizedBox(height: 16),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 150),
                child: _buildRolePortals(
                  context,
                  l10n,
                  isAdmin,
                  isDriver,
                  isMerchant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 200),
              child: _buildLogoutButton(context, ref, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestProfile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: GradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.pushNamed('login'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
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
                        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
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
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
    AppLocalizations l10n,
  ) {
    final authUser = authState is AuthAuthenticated ? authState.user : null;
    final userId = authUser?.id;
    if (userId == null) {
      return const SizedBox.shrink();
    }
    final profileAsync = ref.watch(watchProfileUseCaseProvider(userId));
    final user = profileAsync.valueOrNull ?? authUser;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final initial = (user.fullName?.isNotEmpty ?? false)
        ? user.fullName![0].toUpperCase()
        : (user.username?.isNotEmpty ?? false)
        ? user.username![0].toUpperCase()
        : 'U';

    final roleLabel = _roleLabel(user.role, l10n);

    return PremiumCard(
      padding: const EdgeInsets.all(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          context.colorScheme.primaryContainer.withValues(alpha: 0.35),
          context.colorScheme.surfaceContainerLowest,
        ],
      ),
      borderColor: context.colorScheme.outlineVariant.withValues(alpha: 0.15),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _GradientAvatarRing(
                child: ClipOval(
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: user.avatarUrl?.isNotEmpty == true
                        ? Image.network(
                            user.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildAvatarFallback(context, initial),
                          )
                        : _buildAvatarFallback(context, initial),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _onChangePhoto(context, ref, userId, l10n),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.brandPurple, AppColors.brandViolet],
                      ),
                      border: Border.all(
                        color: context.colorScheme.surface,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3D5B3DF0),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: context.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName ?? user.username ?? l10n.user,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (user.username?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              '@${user.username}',
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppColors.brandPurple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            user.email,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          if (roleLabel != null) ...[
            const SizedBox(height: 10),
            _RoleChip(label: roleLabel),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showEditProfileDialog(context, ref, user, l10n),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              ),
              side: BorderSide(
                color: AppColors.brandPurple.withValues(alpha: 0.5),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.editProfile),
          ),
        ],
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
    WidgetRef ref,
    String userId,
    AppLocalizations l10n,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (file == null || !context.mounted) return;

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
        context.showAppSnackBar(l10n.error);
      }
    }
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    User user,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<_EditProfileResult>(
      context: context,
      builder: (dialogContext) => _EditProfileDialog(
        user: user,
        l10n: l10n,
      ),
    );

    if (result == null || !context.mounted) return;

    final data = <String, dynamic>{};
    if (result.name.isNotEmpty) {
      data['full_name'] = result.name;
    }
    data['username'] = result.username.isEmpty ? null : result.username;
    data['phone'] = result.phone.isEmpty ? null : result.phone;

    try {
      if (data.isNotEmpty) {
        await ref
            .read(updateProfileUseCaseProvider)
            .call(userId: user.id, data: data);
      }
      final dobChanged = result.dateOfBirth != user.dateOfBirth;
      if (dobChanged) {
        await ref.read(updateDateOfBirthUseCaseProvider).call(
              userId: user.id,
              dateOfBirth: result.dateOfBirth,
            );
      }
      if (context.mounted) {
        context.showAppSnackBar(l10n.success);
      }
    } catch (e) {
      if (context.mounted) {
        context.showAppSnackBar(l10n.error);
      }
    }
  }

  Widget _buildSettingsSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeMode themeMode,
    Locale locale,
  ) {
    return _SectionCard(
      title: l10n.settings,
      children: [
        _SectionTile(
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.orderReady,
          title: l10n.wallet,
          onTap: () => context.push('/wallet'),
        ),
        _SectionTile(
          icon: Icons.card_giftcard_rounded,
          color: AppColors.brandViolet,
          title: l10n.rewards,
          subtitle: l10n.rewardsHint,
          onTap: () => context.push('/rewards'),
        ),
        _SectionTile(
          icon: Icons.notifications_outlined,
          color: AppColors.infoLight,
          title: l10n.notifications,
          onTap: () => context.push('/notifications'),
        ),
        _SectionTile(
          icon: themeMode == ThemeMode.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          color: AppColors.brandViolet,
          title: l10n.darkMode,
          trailing: Switch(
            value: themeMode == ThemeMode.dark,
            onChanged: (_) =>
                ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
        ),
        _SectionTile(
          icon: Icons.language_rounded,
          color: AppColors.brandPurple,
          title: l10n.language,
          subtitle: locale.languageCode == 'ar'
              ? l10n.arabicLanguageName
              : l10n.englishLanguageName,
          onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
        ),
      ],
    );
  }

  Widget _buildOrdersAndInvoicesSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return _SectionCard(
      title: l10n.orders,
      children: [
        _SectionTile(
          icon: Icons.receipt_long_rounded,
          color: AppColors.successLight,
          title: l10n.invoice,
          subtitle: l10n.invoiceDetails,
          onTap: () => context.showAppSnackBar(l10n.invoice),
        ),
        _SectionTile(
          icon: Icons.history_rounded,
          color: AppColors.brandPurple,
          title: l10n.previousOrders,
          subtitle: l10n.orderHistory,
          onTap: () => context.push('/market/orders'),
        ),
      ],
    );
  }

  Widget _buildRolePortals(
    BuildContext context,
    AppLocalizations l10n,
    bool isAdmin,
    bool isDriver,
    bool isMerchant,
  ) {
    return _SectionCard(
      title: l10n.rolePortals,
      children: [
        if (isAdmin)
          _PortalTile(
            icon: Icons.admin_panel_settings_outlined,
            gradient: const [AppColors.brandPurple, AppColors.brandViolet],
            label: l10n.admin,
            onTap: () => context.push('/admin'),
          ),
        if (isDriver || isAdmin)
          _PortalTile(
            icon: Icons.delivery_dining_outlined,
            gradient: const [AppColors.brandViolet, AppColors.infoLight],
            label: l10n.driverDashboard,
            onTap: () => context.push('/driver'),
          ),
        if (isMerchant || isAdmin)
          _PortalTile(
            icon: Icons.store_outlined,
            gradient: const [AppColors.orderReady, AppColors.successLight],
            label: l10n.merchantDashboard,
            onTap: () => context.push('/merchant-dashboard'),
          ),
      ],
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return OutlinedButton.icon(
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusDialog),
            ),
            title: Text(l10n.logout),
            content: Text(l10n.areYouSureYouWantToLogout),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
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

class _EditProfileResult {
  const _EditProfileResult({
    required this.name,
    required this.username,
    required this.phone,
    required this.dateOfBirth,
  });

  final String name;
  final String username;
  final String phone;
  final DateTime? dateOfBirth;
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.user, required this.l10n});

  final User user;
  final AppLocalizations l10n;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;
  DateTime? _selectedDate;

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

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusDialog),
      ),
      title: Text(l10n.editProfile),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.fullName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.username,
                prefixText: '@',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: l10n.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
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
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.dateOfBirthPrivacy,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _selectedDate = null),
                icon: const Icon(Icons.clear, size: 16),
                label: Text(l10n.clear),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _EditProfileResult(
              name: _nameController.text.trim(),
              username: _usernameController.text.trim(),
              phone: _phoneController.text.trim(),
              dateOfBirth: _selectedDate,
            ),
          ),
          child: Text(l10n.saveChanges),
        ),
      ],
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
          padding: const EdgeInsets.only(left: 4, bottom: 10),
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
          color: context.colorScheme.surfaceContainerLowest,
          borderColor: context.colorScheme.outlineVariant.withValues(alpha: 0.15),
          child: Column(
            children: List.generate(children.length, (index) {
              final tile = children[index];
              return Column(
                children: [
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
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
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
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
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _PortalTile extends StatelessWidget {
  const _PortalTile({
    required this.icon,
    required this.gradient,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> gradient;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brandPurple.withValues(alpha: 0.25),
            AppColors.brandViolet.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: AppColors.brandPurple.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: 64,
        color: AppColors.brandPurple.withValues(alpha: 0.6),
      ),
    );
  }
}
