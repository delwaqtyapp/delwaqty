import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/features/customer/profile/presentation/app_invitations_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/ota/ota_update_manager.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

final invitationInstallerProvider =
    Provider<Future<(int?, String?)> Function(AppFlavor)>(
      (ref) =>
          (flavor) => downloadAndInstallLatest(flavor),
    );

class AppInvitationsPage extends ConsumerStatefulWidget {
  const AppInvitationsPage({super.key});
  @override
  ConsumerState<AppInvitationsPage> createState() => _AppInvitationsPageState();
}

class _AppInvitationsPageState extends ConsumerState<AppInvitationsPage> {
  AppFlavor? _downloading;
  Future<void> _download(AppFlavor flavor) async {
    if (_downloading != null) return;
    setState(() => _downloading = flavor);
    try {
      // Recheck current authority, never rely on a cached notification or card.
      final channels = await ref.refresh(appInvitationsProvider.future);
      if (!mounted) return;
      if (!channels.contains(flavor)) {
        context.showAppSnackBar(
          AppLocalizations.of(context).appInvitationUnavailable,
        );
        return;
      }
      final result = await ref.read(invitationInstallerProvider)(flavor);
      if (!mounted) return;
      context.showAppSnackBar(
        result.$1 != null
            ? AppLocalizations.of(context).appInvitationInstallReady
            : AppLocalizations.of(context).appInvitationDownloadFailed,
      );
    } catch (_) {
      if (mounted) {
        context.showAppSnackBar(
          AppLocalizations.of(context).appInvitationDownloadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(appInvitationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appInvitationsTitle,
          style: context.textTheme.titleLarge,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          return ref.refresh(appInvitationsProvider.future).then((_) {});
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              gradient: LinearGradient(
                colors: [
                  AppColors.brandPurple.withValues(alpha: .14),
                  context.colorScheme.surface,
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    color: context.colorScheme.primary,
                    size: 36,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.appInvitationsTitle,
                    style: context.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.appInvitationsSubtitle),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...state.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (_, _) => [
                Text(l10n.appInvitationsLoadFailed),
                TextButton(
                  onPressed: () => ref.invalidate(appInvitationsProvider),
                  child: Text(l10n.retry),
                ),
              ],
              data: (channels) => channels.isEmpty
                  ? [Text(l10n.appInvitationsEmpty)]
                  : [
                      for (final flavor in channels)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: PremiumCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      switch (flavor) {
                                        AppFlavor.provider =>
                                          Icons.storefront_rounded,
                                        AppFlavor.driver =>
                                          Icons.delivery_dining_rounded,
                                        _ =>
                                          Icons.admin_panel_settings_outlined,
                                      },
                                      color: context.colorScheme.primary,
                                      size: 32,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(switch (flavor) {
                                        AppFlavor.provider =>
                                          l10n.appInvitationProvider,
                                        AppFlavor.driver =>
                                          l10n.appInvitationDriver,
                                        _ => l10n.appInvitationAdmin,
                                      }, style: context.textTheme.titleMedium),
                                    ),
                                    Icon(
                                      Icons.verified_rounded,
                                      color: context.colorScheme.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(l10n.appInvitationApproved),
                                const SizedBox(height: AppSpacing.md),
                                FilledButton.icon(
                                  onPressed: _downloading != null
                                      ? null
                                      : () => _download(flavor),
                                  icon: _downloading == flavor
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.download_rounded),
                                  label: Text(
                                    _downloading == flavor
                                        ? l10n.appInvitationDownloading
                                        : l10n.appInvitationDownload,
                                    style: context.textTheme.labelLarge
                                        ?.copyWith(
                                          color: context.colorScheme.onPrimary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.appInvitationsFooter, style: context.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
