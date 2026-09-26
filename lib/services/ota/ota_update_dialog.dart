import 'package:flutter/material.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/router/admin_router.dart';
import 'package:delwaqty/core/router/app_router.dart';
import 'package:delwaqty/driver/app_router.dart';
import 'package:delwaqty/provider/app_router.dart';
import 'package:delwaqty/services/ota/ota_update_manager.dart';

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
  final result = await checkForOtaUpdate(flavor);
  if (!result.needsUpdate && !force) return false;

  final navigatorState = _navigatorFor(flavor);
  final navCtx = navigatorState?.context;
  if (navCtx == null && (context == null || !context.mounted)) {
    return false;
  }
  if (navCtx != null && !navCtx.mounted) return false;

  final dialogContext = navCtx ?? context!;
  await showDialog<void>(
    context: dialogContext,
    barrierDismissible: false,
    builder: (_) => _OtaUpdateDialog(
      flavor: flavor,
      result: result,
    ),
  );
  return true;
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
  final dialogContext =
      _navigatorFor(flavor)?.context ?? context;
  if (!dialogContext.mounted) return;
  await showDialog<void>(
    context: dialogContext,
    barrierDismissible: false,
    builder: (_) => _OtaUpdateDialog(flavor: flavor, result: result),
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

class _OtaUpdateDialog extends StatefulWidget {
  const _OtaUpdateDialog({required this.flavor, required this.result});

  final AppFlavor flavor;
  final OtaCheckResult result;

  @override
  State<_OtaUpdateDialog> createState() => _OtaUpdateDialogState();
}

class _OtaUpdateDialogState extends State<_OtaUpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  bool _downloadFailed = false;
  String? _downloadError;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.system_update_alt,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAr ? 'يتوفر تحديث جديد' : 'A new update is available',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_downloading) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_download_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(isAr ? 'جاري تحميل التحديث…' : 'Downloading…'),
                        ),
                        Text(
                          '${(_progress * 100).clamp(0, 100).round()}%',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_downloadFailed) ...[
            Text(
              isAr
                  ? _downloadError == 'needs_install_permission'
                      ? 'أكّد السماح بالتثبيت من مصادر غير معروفة في الخطوة التالية ثم أعد المحاولة.'
                      : 'تعذر تحميل التحديث. تأكد من الاتصال بالإنترنت ثم أعد المحاولة.'
                  : _downloadError == 'needs_install_permission'
                      ? 'Allow installing from unknown sources in the next step, then retry.'
                      : 'Could not download the update. Check your connection and try again.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ] else ...[
            Text(
              isAr
                  ? 'نسختك الحالية ${widget.result.current} والنسخة الأحدث ${widget.result.latest}.'
                  : 'You are on build ${widget.result.current}; the latest is ${widget.result.latest}.',
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'سيتم تنزيل التحديث وتثبيته مباشرة دون إعادة تثبيت التطبيق.'
                  : 'The update will be downloaded and installed without reinstalling the app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        if (!_downloadFailed) ...[
          TextButton(
            onPressed: _downloading ? null : () => Navigator.of(context).pop(),
            child: Text(isAr ? 'لاحقًا' : 'Later'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isAr ? 'إغلاق' : 'Close'),
          ),
        ],
        if (!_downloading && !_downloadFailed)
          FilledButton(
            onPressed: _startUpdate,
            child: Text(isAr ? 'تحديث الآن' : 'Update now'),
          ),
      ],
    );
  }

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _downloadFailed = false;
    });
    final result = await downloadAndInstallLatest(
      widget.flavor,
      onProgress: (f) => setState(() => _progress = f),
    );
    final success = result.$1 != null;
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _downloadFailed = !success;
      _downloadError = result.$2;
    });
    if (success) {
      Navigator.of(context).pop();
    }
  }
}