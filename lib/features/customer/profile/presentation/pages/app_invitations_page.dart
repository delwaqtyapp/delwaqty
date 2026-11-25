import 'dart:io';

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

/// Downloads the APK for [flavor] only (no install), reporting progress.
final invitationDownloaderProvider =
    Provider<
      Future<OtaDownloadResult> Function(AppFlavor, void Function(double))
    >(
      (ref) =>
          (flavor, onProgress) =>
              downloadLatestApk(flavor, onProgress: onProgress),
    );

/// Fetches the release manifest used to compare installed versions.
final invitationManifestProvider = Provider<Future<OtaManifest?> Function()>(
  (ref) => fetchOtaManifest,
);

class AppInvitationsPage extends ConsumerStatefulWidget {
  const AppInvitationsPage({super.key});
  @override
  ConsumerState<AppInvitationsPage> createState() => _AppInvitationsPageState();
}

class _AppInvitationsPageState extends ConsumerState<AppInvitationsPage>
    with WidgetsBindingObserver {
  AppFlavor? _downloading;
  double _progress = 0;
  File? _readyFile;
  AppFlavor? _readyFlavor;

  /// Manifest version of the APK currently waiting for install. The ready
  /// state clears only once the installed versionCode reaches THIS version.
  int? _readyVersion;
  OtaManifest? _manifest;
  final Map<AppFlavor, int?> _installed = {};
  bool _statusesRequested = false;
  bool _statusesLoaded = false;
  List<AppFlavor> _channels = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the system installer (or from anywhere else) re-reads
    // the installed versions, so a completed install settles the card on
    // Open instead of offering the same APK again.
    if (state == AppLifecycleState.resumed && _channels.isNotEmpty) {
      _loadStatuses(_channels);
    }
  }

  /// Loads the release manifest and each invited app's installed version, so
  /// a card can offer Download, Update or Open instead of re-offering the
  /// same APK forever.
  Future<void> _loadStatuses(List<AppFlavor> channels) async {
    OtaManifest? manifest;
    try {
      manifest = await ref.read(invitationManifestProvider)();
    } catch (_) {
      manifest = null;
    }
    final installed = <AppFlavor, int?>{};
    for (final flavor in channels) {
      installed[flavor] = await installedVersionCode(
        packageNameForFlavor(flavor),
      );
    }
    if (!mounted) return;
    setState(() {
      _manifest = manifest;
      _installed
        ..clear()
        ..addAll(installed);
      _statusesLoaded = true;
      // A completed install clears the ready APK once it reaches the
      // downloaded version; a partial install keeps the Install button.
      final readyFlavor = _readyFlavor;
      final readyVersion = _readyVersion;
      if (readyFlavor != null && readyVersion != null) {
        final code = installed[readyFlavor];
        if (code != null && code >= readyVersion) {
          _readyFlavor = null;
          _readyFile = null;
          _readyVersion = null;
        }
      }
    });
  }

  Future<void> _download(AppFlavor flavor) async {
    if (_downloading != null) return;
    setState(() {
      _downloading = flavor;
      _progress = 0;
      _readyFlavor = null;
      _readyFile = null;
      _readyVersion = null;
    });
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
      final result = await ref.read(invitationDownloaderProvider)(flavor, (
        fraction,
      ) {
        if (mounted) setState(() => _progress = fraction);
      });
      if (!mounted) return;
      final file = result.file;
      if (file == null) {
        context.showAppSnackBar(
          AppLocalizations.of(context).appInvitationDownloadFailed,
        );
        return;
      }
      setState(() {
        _readyFile = file;
        _readyFlavor = flavor;
        // The verified version of THIS artifact, not a later manifest
        // snapshot: the ready state clears only when the installed
        // versionCode reaches the version actually downloaded.
        _readyVersion = result.version;
      });
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

  Future<void> _install(AppFlavor flavor) async {
    final file = _readyFile;
    if (file == null) return;
    // Recheck current authority: the invitation may have been revoked while
    // the APK was downloading.
    try {
      final channels = await ref.refresh(appInvitationsProvider.future);
      if (!mounted) return;
      if (!channels.contains(flavor)) {
        setState(() {
          _readyFlavor = null;
          _readyFile = null;
          _readyVersion = null;
        });
        context.showAppSnackBar(
          AppLocalizations.of(context).appInvitationUnavailable,
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      context.showAppSnackBar(
        AppLocalizations.of(context).appInvitationDownloadFailed,
      );
      return;
    }
    final error = await installDownloadedApk(file);
    if (!mounted) return;
    if (error != null) {
      context.showAppSnackBar(
        AppLocalizations.of(context).appInvitationDownloadFailed,
      );
      return;
    }
    context.showAppSnackBar(
      AppLocalizations.of(context).appInvitationInstallReady,
    );
    // The install intent returns before the system finishes installing; the
    // resume observer settles the card when the user comes back.
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
          _statusesRequested = false;
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
              data: (channels) {
                _channels = channels;
                if (!_statusesRequested && channels.isNotEmpty) {
                  _statusesRequested = true;
                  // Load manifest + installed versions after the frame; the
                  // statuses only change each card's button state.
                  Future(() => _loadStatuses(channels));
                }
                return channels.isEmpty
                    ? [Text(l10n.appInvitationsEmpty)]
                    : [
                        for (final flavor in channels)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
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
                                        child: Text(
                                          switch (flavor) {
                                            AppFlavor.provider =>
                                              l10n.appInvitationProvider,
                                            AppFlavor.driver =>
                                              l10n.appInvitationDriver,
                                            _ => l10n.appInvitationAdmin,
                                          },
                                          style: context.textTheme.titleMedium,
                                        ),
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
                                  _buildAction(context, l10n, flavor),
                                ],
                              ),
                            ),
                          ),
                      ];
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.appInvitationsFooter, style: context.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  /// Card action for [flavor]: a progress bar with percentage while the
  /// download runs, an Install button once the verified file is on disk, an
  /// Open button when the installed copy is already current, and
  /// Download/Update otherwise.
  Widget _buildAction(
    BuildContext context,
    AppLocalizations l10n,
    AppFlavor flavor,
  ) {
    final labelStyle = context.textTheme.labelLarge?.copyWith(
      color: context.colorScheme.onPrimary,
    );
    // Statuses (manifest + installed versions) are still loading: show an
    // indeterminate state instead of defaulting to Download.
    if (!_statusesLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_manifest == null) {
      // The release manifest could not be read: the installed/current state
      // is unknown, so offer a retry instead of a bare Download.
      return Row(
        children: [
          Expanded(
            child: Text(
              l10n.appInvitationsLoadFailed,
              style: context.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => _loadStatuses(_channels),
            child: Text(l10n.retry),
          ),
        ],
      );
    }
    if (_downloading == flavor) {
      final percent = (_progress * 100).clamp(0, 100).round();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${l10n.appInvitationDownloading} $percent%',
            style: context.textTheme.bodySmall,
          ),
        ],
      );
    }
    if (_readyFlavor == flavor) {
      return FilledButton.icon(
        onPressed: () => _install(flavor),
        icon: const Icon(Icons.system_update_alt_rounded),
        label: Text(l10n.appInvitationInstall, style: labelStyle),
      );
    }
    final installed = _installed[flavor];
    final latest = _manifest?.forFlavor(flavor)?.version;
    final upToDate = installed != null && latest != null && installed >= latest;
    if (upToDate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _downloading != null
                ? null
                : () => launchInstalledApp(packageNameForFlavor(flavor)),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.appInvitationOpen, style: labelStyle),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.appInvitationUpToDate, style: context.textTheme.bodySmall),
        ],
      );
    }
    final isUpdate = installed != null && latest != null;
    return FilledButton.icon(
      onPressed: _downloading != null ? null : () => _download(flavor),
      icon: const Icon(Icons.download_rounded),
      label: Text(
        isUpdate ? l10n.appInvitationUpdate : l10n.appInvitationDownload,
        style: labelStyle,
      ),
    );
  }
}
