import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Full-screen barcode scanner used by the in-app cashier (scan-to-add) and
/// the product form (scan-to-fill). Returns the scanned/typed barcode string
/// via [Navigator.pop], or null when cancelled.
///
/// Camera permission is requested explicitly so the merchant sees an Arabic
/// explanation and a settings shortcut when access was denied permanently,
/// instead of a dead preview. Typing the barcode by hand is always offered:
/// phone cameras struggle with wrinkled pharmacy foil and dim shelves.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  /// Pushes the scanner and resolves with the barcode, or null on cancel.
  static Future<String?> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
  }

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

enum _PermissionUiState { checking, granted, denied, permanentlyDenied }

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    // One good read is enough; duplicates would pop the page twice.
    detectionSpeed: DetectionSpeed.noDuplicates,
    // Retail/pharmacy reality: EAN-13/UPC on packaging, Code128 on shelves,
    // QR on some suppliers. Leaving formats empty also enables PDF417 etc.
    // which mis-fires on IDs and cards, so keep the set explicit.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );
  _PermissionUiState _permission = _PermissionUiState.checking;
  bool _popped = false;
  // While the manual-entry sheet is open, camera detection must not fire:
  // onDetect would pop the SHEET (the top route) and leave the scanner
  // stuck underneath. Detection is both ignored here and paused on the
  // controller for the duration of the sheet.
  bool _manualEntryOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  /// App lifecycle: release the camera while backgrounded, and re-check
  /// permission on resume so "Open Settings -> grant -> return" flips the
  /// page to the live preview without re-opening it. Status is only checked
  /// here, never re-requested, to avoid looping the system dialog.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_permission == _PermissionUiState.granted && !_manualEntryOpen) {
        _controller.stop().catchError((_) {});
      }
    } else if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    if (_popped) return;
    PermissionStatus status;
    try {
      status = await Permission.camera.status;
    } catch (_) {
      status = PermissionStatus.permanentlyDenied;
    }
    if (!mounted) return;
    if (status.isGranted) {
      if (_permission != _PermissionUiState.granted) {
        // The preview mounts now and auto-starts the controller; starting
        // it here as well collides with its own start.
        setState(() => _permission = _PermissionUiState.granted);
      } else if (!_manualEntryOpen) {
        _controller.start().catchError((_) {});
      }
    } else {
      final next = status.isPermanentlyDenied || status.isRestricted
          ? _PermissionUiState.permanentlyDenied
          : _PermissionUiState.denied;
      if (_permission != next) setState(() => _permission = next);
    }
  }

  Future<void> _checkPermission() async {
    PermissionStatus status;
    try {
      status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
    } catch (_) {
      // Platforms without the plugin (tests, desktop) never get a preview;
      // show the permission explanation instead of crashing.
      status = PermissionStatus.permanentlyDenied;
    }
    if (!mounted) return;
    setState(() {
      if (status.isGranted) {
        _permission = _PermissionUiState.granted;
      } else if (status.isPermanentlyDenied || status.isRestricted) {
        _permission = _PermissionUiState.permanentlyDenied;
      } else {
        _permission = _PermissionUiState.denied;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _finish(String value) {
    final code = value.trim();
    if (code.isEmpty || _popped) return;
    _popped = true;
    Navigator.of(context).pop(code);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_popped || _manualEntryOpen) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _finish(raw);
        return;
      }
    }
  }

  Future<void> _openManualEntry() async {
    _manualEntryOpen = true;
    // Pause the camera while the sheet covers the preview; resumed in
    // finally when the merchant cancels (a typed code pops the scanner
    // instead, so no resume happens after a successful entry).
    try {
      await _controller.stop();
    } catch (_) {}
    try {
      final l10n = AppLocalizations.of(context);
      final ctrl = TextEditingController();
      final code = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (sheetCtx) {
          final l10nSheet = AppLocalizations.of(sheetCtx);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10nSheet.scannerManualHint,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.barcode_reader),
                      ),
                      onSubmitted: (v) => Navigator.of(sheetCtx).pop(v.trim()),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(sheetCtx).pop(ctrl.text.trim()),
                      child: Text(l10nSheet.confirm),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (!mounted || code == null || code.isEmpty) return;
      _finish(code);
    } finally {
      _manualEntryOpen = false;
      if (mounted && !_popped && _permission == _PermissionUiState.granted) {
        try {
          await _controller.start();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.scannerTitle),
        actions: [
          if (_permission == _PermissionUiState.granted)
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                final on = state.torchState == TorchState.on;
                return IconButton(
                  tooltip: l10n.scannerTorch,
                  icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                  onPressed: () => _controller.toggleTorch(),
                );
              },
            ),
          IconButton(
            tooltip: l10n.scannerEnterManually,
            icon: const Icon(Icons.keyboard_alt_outlined),
            onPressed: _openManualEntry,
          ),
        ],
      ),
      body: switch (_permission) {
        _PermissionUiState.checking => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        _PermissionUiState.granted => _buildScanner(context),
        _PermissionUiState.denied => _buildPermissionRequest(
          context,
          l10n,
          permanently: false,
        ),
        _PermissionUiState.permanentlyDenied => _buildPermissionRequest(
          context,
          l10n,
          permanently: true,
        ),
      },
    );
  }

  Widget _buildScanner(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        // Aim frame: plain bordered box, deliberately token-styled.
        Center(
          child: Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.brandPurple, width: 3),
              borderRadius: AppSpacing.borderRadiusLg,
            ),
          ),
        ),
        PositionedDirectional(
          bottom: AppSpacing.xxl,
          start: AppSpacing.lg,
          end: AppSpacing.lg,
          child: Text(
            l10n.scannerAimHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionRequest(
    BuildContext context,
    AppLocalizations l10n, {
    required bool permanently,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: Colors.white,
              size: AppSpacing.d72,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.scannerPermissionNeeded,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: permanently ? openAppSettings : _checkPermission,
              child: Text(
                permanently
                    ? l10n.scannerOpenSettings
                    : l10n.scannerGrantPermission,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _openManualEntry,
              child: Text(
                l10n.scannerEnterManually,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.brandLavender,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
