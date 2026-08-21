import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
  String? _email;
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
        _email = user.email;
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
        authState.whenOrNull(authenticated: (user) => user.isBiometricEnabled) ??
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
      final store = ref.read(biometricAuthStoreProvider);
      final existing = await store.credentialsFor(userId);
      if (existing == null) {
        final password = await _promptPassword();
        if (password == null) return;
        await store.saveCredentials(
          userId: userId,
          email: _email ?? '',
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
    passwordController.dispose();
    return confirmed == true && password.isNotEmpty ? password : null;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fingerprintLogin),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(context, l10n.security, [
            SwitchListTile(
              secondary: Icon(
                Icons.fingerprint_rounded,
                color: context.colorScheme.primary,
              ),
              title: Text(l10n.fingerprintLogin),
              subtitle: Text(l10n.fingerprintLoginDescription),
              value: _enabled,
              onChanged: _toggle,
            ),
          ]),
          if (_email != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _email!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (_allCredentials.length > 1) ...[
            const SizedBox(height: 24),
            _buildSection(context, l10n.savedAccounts, [
              for (final cred in _allCredentials)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      cred.email.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  title: Text(cred.email),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeCredential(cred),
                  ),
                ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          color: context.colorScheme.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
