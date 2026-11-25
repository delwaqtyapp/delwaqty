import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';

class FingerprintLoginPage extends ConsumerStatefulWidget {
  const FingerprintLoginPage({super.key});

  @override
  ConsumerState<FingerprintLoginPage> createState() =>
      _FingerprintLoginPageState();
}

class _FingerprintLoginPageState extends ConsumerState<FingerprintLoginPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;
  bool _enabled = false;
  String? _loginIdentifier;
  String? _userId;
  List<BiometricCredentials> _allCredentials = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final authState = ref.read(authStateProvider);
    final user = authState.whenOrNull(authenticated: (user) => user);
    if (user != null && mounted) {
      setState(() {
        _userId = user.id;
        // The LOGIN identifier (phone or username), never the account
        // email: email is not a login identifier (441).
        _loginIdentifier = biometricLoginIdentifier(
          phone: user.phone,
          username: user.username,
        );
      });
    }
    await _loadStatus();
    await _loadAllCredentials();
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (mounted) setState(() => _biometricAvailable = canCheck);
    } catch (_) {}
  }

  Future<void> _loadStatus() async {
    final authState = ref.read(authStateProvider);
    final enabled =
        authState.whenOrNull(
          authenticated: (user) => user.isBiometricEnabled,
        ) ??
        false;
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _loadAllCredentials() async {
    final store = ref.read(biometricAuthStoreProvider);
    final userIds = await store.allUserIds();
    final creds = <BiometricCredentials>[];
    for (final uid in userIds) {
      final c = await store.credentialsFor(uid);
      if (c != null) creds.add(c);
    }
    if (mounted) setState(() => _allCredentials = creds);
  }

  Future<void> _toggle(bool value) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    if (value) {
      if (!_biometricAvailable) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.biometricNotAvailable),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final identifier = _loginIdentifier;
      if (identifier == null || identifier.isEmpty) {
        // No phone or username on the account: there is no login
        // identifier to replay, so biometric login cannot work.
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.tryAgain),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final store = ref.read(biometricAuthStoreProvider);
      final existing = await store.credentialsFor(userId);
      if (existing == null) {
        final password = await _promptPassword();
        if (password == null) return;
        await store.saveCredentials(
          userId: userId,
          identifier: identifier,
          password: password,
        );
      }
      await ref
          .read(authStateProvider.notifier)
          .updateBiometricEnabled(enabled: true);
      if (mounted) {
        setState(() => _enabled = true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.fingerprintEnabled),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadAllCredentials();
    } else {
      final store = ref.read(biometricAuthStoreProvider);
      await store.clearForUser(userId);
      await ref
          .read(authStateProvider.notifier)
          .updateBiometricEnabled(enabled: false);
      if (mounted) {
        setState(() => _enabled = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.fingerprintDisabled),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadAllCredentials();
    }
  }

  Future<String?> _promptPassword() async {
    final l10n = AppLocalizations.of(context);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.enableFingerprint),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.enterPasswordForFingerprint),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => AppValidators.password(v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    final password = passwordController.text;
    // Deliberately NOT disposed here: the dialog's exit animation still
    // builds the field for a few frames after pop, and disposing the
    // controller immediately races it (used-after-disposed). The
    // controller is tiny and this dialog is rare, so it is left for GC.
    return confirmed == true && password.isNotEmpty ? password : null;
  }

  Future<void> _confirmRemoveCredential(BiometricCredentials cred) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.delete,
      message: l10n.removeSavedAccountConfirm(cred.identifier),
      confirmLabel: l10n.delete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _removeCredential(cred);
  }

  Future<void> _removeCredential(BiometricCredentials cred) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final store = ref.read(biometricAuthStoreProvider);
    await store.clearForUser(cred.userId);
    if (cred.userId == _userId) {
      await ref
          .read(authStateProvider.notifier)
          .updateBiometricEnabled(enabled: false);
      if (mounted) setState(() => _enabled = false);
    }
    await _loadAllCredentials();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.fingerprintDisabled),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fingerprintLogin),
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.brandPurpleDeep,
                  AppColors.brandPurple,
                  AppColors.brandViolet,
                ],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPurple.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.fingerprintLogin,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_loginIdentifier != null &&
                          _loginIdentifier!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _loginIdentifier!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSection(context, l10n.security, [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              secondary: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              title: Text(
                l10n.fingerprintLogin,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                l10n.fingerprintLoginDescription,
                style: context.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              value: _enabled,
              onChanged: _toggle,
            ),
          ]),
          if (_allCredentials.length > 1) ...[
            const SizedBox(height: 20),
            _buildSection(context, l10n.savedAccounts, [
              for (var i = 0; i < _allCredentials.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 66,
                    endIndent: 16,
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _allCredentials[i].identifier.isNotEmpty
                          ? _allCredentials[i].identifier[0].toUpperCase()
                          : '?',
                      style: context.textTheme.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    _allCredentials[i].identifier,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.errorLight,
                    ),
                    onPressed: () =>
                        _confirmRemoveCredential(_allCredentials[i]),
                  ),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
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
                  gradient: const LinearGradient(
                    colors: [AppColors.brandPurple, AppColors.brandViolet],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: cs.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
