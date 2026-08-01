import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

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

    final isAdmin =
        authState is AuthAuthenticated &&
        (authState.user.role == 'admin' || authState.user.role == 'owner');
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedFadeIn(
            child: _buildProfileHeader(context, ref, authState, l10n),
          ),
          const SizedBox(height: 24),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 100),
            child: _buildSettingsSection(context, ref, l10n, themeMode, locale),
          ),
          const SizedBox(height: 12),
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
    );
  }

  Widget _buildGuestProfile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 80,
                color: context.colorScheme.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.guestMode,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.guestModeHint,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.pushNamed('login'),
                child: Text(l10n.login),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.pushNamed('register'),
                child: Text(l10n.register),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.primary,
                  border: Border.all(
                    color: context.colorScheme.onPrimary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: user.avatarUrl?.isNotEmpty == true
                      ? Image.network(
                          user.avatarUrl!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildAvatarFallback(context, initial),
                        )
                      : _buildAvatarFallback(context, initial),
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
                      color: context.colorScheme.primary,
                      border: Border.all(
                        color: context.colorScheme.surface,
                        width: 2,
                      ),
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
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (user.username?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              '@${user.username}',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w600,
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showEditProfileDialog(context, ref, user, l10n),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.editProfile),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(BuildContext context, String initial) {
    return Center(
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
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final url = await ref
          .read(uploadAvatarUseCaseProvider)
          .call(
            userId: userId,
            bytes: bytes,
            fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
      await ref
          .read(updateProfileUseCaseProvider)
          .call(userId: userId, data: {'avatar_url': url});
      ref.invalidate(watchProfileUseCaseProvider(userId));
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
    final nameController = TextEditingController(text: user.fullName ?? '');
    final usernameController = TextEditingController(text: user.username ?? '');
    final phoneController = TextEditingController(text: user.phone ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editProfile),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.fullName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: l10n.username,
                  prefixText: '@',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: l10n.phone),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.saveChanges),
          ),
        ],
      ),
    );

    nameController.dispose();
    usernameController.dispose();
    phoneController.dispose();

    if (saved != true) return;

    final data = <String, dynamic>{};
    if (nameController.text.trim().isNotEmpty) {
      data['full_name'] = nameController.text.trim();
    }
    data['username'] = usernameController.text.trim().isEmpty
        ? null
        : usernameController.text.trim();
    data['phone'] = phoneController.text.trim().isEmpty
        ? null
        : phoneController.text.trim();

    try {
      await ref
          .read(updateProfileUseCaseProvider)
          .call(userId: user.id, data: data);
      ref.invalidate(watchProfileUseCaseProvider(user.id));
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l10n.wallet),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/wallet'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.notifications),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/notifications'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            title: Text(l10n.darkMode),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggleTheme(),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.language),
            subtitle: Text(
              locale.languageCode == 'ar'
                  ? l10n.arabicLanguageName
                  : l10n.englishLanguageName,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersAndInvoicesSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.receipt_long_rounded,
              color: AppColors.successLight,
            ),
            title: Text(l10n.invoice),
            subtitle: Text(l10n.invoiceDetails),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.showAppSnackBar(l10n.invoice),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.history_rounded, color: cs.primary),
            title: Text(l10n.previousOrders),
            subtitle: Text(l10n.orderHistory),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/market/orders'),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePortals(
    BuildContext context,
    AppLocalizations l10n,
    bool isAdmin,
    bool isDriver,
    bool isMerchant,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAdmin) ...[
          FilledButton.tonalIcon(
            onPressed: () => context.push('/admin'),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(l10n.admin),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isDriver || isAdmin) ...[
          FilledButton.tonalIcon(
            onPressed: () => context.push('/driver'),
            icon: const Icon(Icons.delivery_dining_outlined),
            label: Text(l10n.driverDashboard),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (isMerchant || isAdmin) ...[
          FilledButton.tonalIcon(
            onPressed: () => context.push('/merchant-dashboard'),
            icon: const Icon(Icons.store_outlined),
            label: Text(l10n.merchantDashboard),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
