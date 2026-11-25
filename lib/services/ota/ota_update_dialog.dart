import 'dart:io';

import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/router/admin_router.dart';
import 'package:delwaqty/core/router/app_router.dart';
import 'package:delwaqty/driver/app_router.dart';
import 'package:delwaqty/gen/assets.gen.dart';
import 'package:delwaqty/provider/app_router.dart';
import 'package:delwaqty/services/ota/ota_update_manager.dart';

final Set<AppFlavor> _openUpdateFlavors = {};

/// Shows a single update dialog when a newer build is available for the
/// running flavor. Returns true if a dialog (update / failure) was shown.
///
/// The dialog is shown on the app's router navigator key (per flavor), so it
/// works even when a plain root `BuildContext` has no Navigator ancestor.
Future<bool> showOtaUpdateIfAvailable({
  BuildContext? context,
  required AppFlavor flavor,
  bool force = false,
}) async {
  if (_openUpdateFlavors.contains(flavor)) return false;
  final result = await checkForOtaUpdate(flavor);
  if (!result.needsUpdate) {
    // The running build caught up: any earlier install handoff is done.
    await clearOtaInstallHandoff(flavor);
    if (!force) return false;
  } else if (!force) {
    // The installer was already opened for this exact version and the
    // running build still has not changed: do not re-offer on every
    // resume (the update loop). The About-page manual check (force)
    // still shows the dialog.
    final handedOff = await otaInstallHandedOffVersion(flavor);
    if (suppressAutoOtaOffer(
      current: result.current,
      latest: result.latest,
      handedOff: handedOff,
    )) {
      return false;
    }
  }

  final navigatorState = _navigatorFor(flavor);
  final navCtx = navigatorState?.context;
  if (navCtx == null && (context == null || !context.mounted)) {
    return false;
  }
  if (navCtx != null && !navCtx.mounted) return false;

  final dialogContext = navCtx ?? context!;
  if (!_openUpdateFlavors.add(flavor)) return false;
  try {
    await showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (_) => OtaUpdateDialog(flavor: flavor, result: result),
    );
    return true;
  } finally {
    _openUpdateFlavors.remove(flavor);
  }
}

/// Shows the update dialog for an ALREADY-verified [result] (the caller has
/// already run [checkForOtaUpdate] and confirmed `needsUpdate`). Unlike
/// [showOtaUpdateIfAvailable] this does not re-fetch the manifest, so it runs
/// instantly from the About page.
Future<void> showUpdateAvailableAndDownload({
  required BuildContext context,
  required AppFlavor flavor,
  required OtaCheckResult result,
}) async {
  final dialogContext = _navigatorFor(flavor)?.context ?? context;
  if (!dialogContext.mounted) return;
  await showDialog<void>(
    context: dialogContext,
    barrierDismissible: false,
    builder: (_) => OtaUpdateDialog(flavor: flavor, result: result),
  );
}

NavigatorState? _navigatorFor(AppFlavor flavor) {
  switch (flavor) {
    case AppFlavor.admin:
      return adminNavigatorKey.currentState;
    case AppFlavor.customer:
      return rootNavigatorKey.currentState;
    case AppFlavor.driver:
      return driverRootNavigatorKey.currentState;
    case AppFlavor.provider:
      return providerRootNavigatorKey.currentState;
  }
}

/// Platform calls the dialog needs, injectable so the flow can be tested.
class OtaUpdateActions {
  const OtaUpdateActions({
    required this.download,
    required this.canInstall,
    required this.install,
  });

  factory OtaUpdateActions.forFlavor(
    AppFlavor flavor, {
    OtaCheckResult? offered,
  }) => OtaUpdateActions(
    download: (onProgress) =>
        downloadLatestApk(flavor, onProgress: onProgress, offered: offered),
    canInstall: canRequestPackageInstalls,
    install: installDownloadedApk,
  );

  final Future<OtaDownloadResult> Function(void Function(double) onProgress)
  download;
  final Future<bool> Function() canInstall;

  /// Returns null on success, else the native error code.
  final Future<String?> Function(File file) install;
}

enum OtaDialogStep {
  idle,
  downloading,
  ready,
  awaitingPermission,
  downloadFailed,
  installFailed,
  checksumFailed,
}

/// The update notice. It stays on screen until the new version is installed
/// (the OS then restarts the app): after the download it offers "Install" for
/// the file already on disk, and after the user grants "install unknown apps"
/// it resumes the install by itself when the app returns to the foreground.
class OtaUpdateDialog extends StatefulWidget {
  const OtaUpdateDialog({
    super.key,
    required this.flavor,
    required this.result,
    this.actions,
  });

  final AppFlavor flavor;
  final OtaCheckResult result;
  final OtaUpdateActions? actions;

  @override
  State<OtaUpdateDialog> createState() => _OtaUpdateDialogState();
}

class _OtaUpdateDialogState extends State<OtaUpdateDialog>
    with WidgetsBindingObserver {
  late final OtaUpdateActions _actions =
      widget.actions ??
      OtaUpdateActions.forFlavor(widget.flavor, offered: widget.result);
  OtaDialogStep _step = OtaDialogStep.idle;
  double _progress = 0;
  File? _file;
  bool _installing = false;

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
    if (state == AppLifecycleState.resumed &&
        _step == OtaDialogStep.awaitingPermission &&
        _file != null) {
      _resumeAfterPermission();
    }
  }

  Future<void> _resumeAfterPermission() async {
    final allowed = await _actions.canInstall();
    if (!mounted || _step != OtaDialogStep.awaitingPermission) return;
    // Still not allowed: keep the calm instructions, no error.
    if (allowed) await _install();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final busy = _step == OtaDialogStep.downloading;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image(
                  image: Assets.egypt.delwaqtyLogoMark.provider(),
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _step == OtaDialogStep.ready ||
                        _step == OtaDialogStep.awaitingPermission ||
                        _step == OtaDialogStep.installFailed
                    ? l10n.otaReadyTitle
                    : l10n.otaTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image(
                image: Assets.egypt.delwaqtyLogoMark.provider(),
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 14),
            if (busy)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_download_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.otaDownloading)),
                      Text('${(_progress * 100).clamp(0, 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _progress, minHeight: 8),
                ],
              )
            else
              ..._body(l10n, scheme),
          ],
        ),
        actions: [
          if (_step == OtaDialogStep.idle ||
              _step == OtaDialogStep.downloadFailed ||
              _step == OtaDialogStep.installFailed ||
              _step == OtaDialogStep.awaitingPermission ||
              _step == OtaDialogStep.checksumFailed)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.otaLater),
            ),
          if (_step == OtaDialogStep.idle ||
              _step == OtaDialogStep.checksumFailed)
            FilledButton(
              onPressed: _startUpdate,
              child: Text(l10n.otaUpdateNow),
            ),
          if (_step == OtaDialogStep.downloadFailed)
            FilledButton(onPressed: _startUpdate, child: Text(l10n.otaRetry)),
          if (_step == OtaDialogStep.ready ||
              _step == OtaDialogStep.awaitingPermission ||
              _step == OtaDialogStep.installFailed)
            FilledButton(
              onPressed: _installing ? null : _install,
              child: Text(l10n.otaInstall),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(AppLocalizations l10n, ColorScheme scheme) {
    switch (_step) {
      case OtaDialogStep.ready:
        return [Text(l10n.otaReadyBody)];
      case OtaDialogStep.awaitingPermission:
        return [Text(l10n.otaPermissionBody)];
      case OtaDialogStep.downloadFailed:
        return [
          Text(l10n.otaDownloadFailed, style: TextStyle(color: scheme.error)),
        ];
      case OtaDialogStep.installFailed:
        return [
          Text(l10n.otaInstallFailed, style: TextStyle(color: scheme.error)),
        ];
      case OtaDialogStep.checksumFailed:
        return [
          Text(l10n.otaChecksumFailed, style: TextStyle(color: scheme.error)),
        ];
      case OtaDialogStep.idle:
      case OtaDialogStep.downloading:
        return [
          Text(l10n.otaIntro),
          const SizedBox(height: 8),
          Text(l10n.otaIntroHint, style: Theme.of(context).textTheme.bodySmall),
        ];
    }
  }

  Future<void> _startUpdate() async {
    setState(() {
      _step = OtaDialogStep.downloading;
      _progress = 0;
    });
    final download = await _actions.download((f) {
      if (mounted) setState(() => _progress = f);
    });
    if (!mounted) return;
    final file = download.file;
    if (file == null) {
      setState(() {
        _step = download.error == 'checksum_mismatch'
            ? OtaDialogStep.checksumFailed
            : OtaDialogStep.downloadFailed;
      });
      return;
    }
    _file = file;
    setState(() => _step = OtaDialogStep.ready);
    await _install();
  }

  /// Installs the file that is already on disk. Never downloads again.
  Future<void> _install() async {
    final file = _file;
    if (file == null || _installing) return;
    _installing = true;
    setState(() {});
    final error = await _actions.install(file);
    _installing = false;
    if (!mounted) return;
    if (error == 'artifact_missing' || error == 'artifact_invalid') {
      _file = null;
      await _startUpdate();
      return;
    }
    if (error == null) {
      // The installer was opened for this version; remember it so the
      // automatic check does not re-offer the same update on every resume
      // while the install is still pending.
      await markOtaInstallHandedOff(widget.flavor, widget.result.latest);
      if (!mounted) return;
    }
    setState(() {
      if (error == null) {
        // The system installer is open. Keep the notice and its Install
        // button: it only goes away when the new version replaces this one.
        _step = OtaDialogStep.ready;
      } else if (error == 'needs_install_permission') {
        _step = OtaDialogStep.awaitingPermission;
      } else {
        _step = OtaDialogStep.installFailed;
      }
    });
  }
}
