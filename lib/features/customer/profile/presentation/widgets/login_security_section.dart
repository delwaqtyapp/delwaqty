import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Edit Profile > Login and security.
///
/// * Show the password saved ON THIS DEVICE (the fingerprint-login store).
///   The server never has a readable password, so this only works when the
///   user turned on fingerprint login here. Shown only after the phone's own
///   lock (fingerprint or screen lock) confirms it is the owner.
/// * Set or change the login password (useful after Google/Facebook signup)
///   behind the same device-lock check, so a borrowed unlocked phone cannot
///   take over the account. Also refreshes the device-saved copy.
class LoginSecuritySection extends ConsumerStatefulWidget {
  const LoginSecuritySection({
    super.key,
    required this.userId,
    this.confirmOwner,
  });

  final String userId;

  /// Test seam: replaces the real fingerprint / screen-lock prompt.
  final Future<bool> Function(String reason)? confirmOwner;

  @override
  ConsumerState<LoginSecuritySection> createState() =>
      _LoginSecuritySectionState();
}

class _LoginSecuritySectionState extends ConsumerState<LoginSecuritySection> {
  bool _busy = false;

  Future<bool> _confirm(String reason) async {
    final override = widget.confirmOwner;
    if (override != null) return override(reason);
    try {
      // Biometric or the phone's PIN/pattern: whatever the owner set up.
      return await LocalAuthentication().authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showSaved() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      if (!await _confirm(l10n.deviceLockReason)) {
        _toast(l10n.deviceLockFailed);
        return;
      }
      final creds = await ref
          .read(biometricAuthStoreProvider)
          .credentialsFor(widget.userId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.savedPasswordTitle),
          content: creds == null
              ? Text(l10n.noSavedPassword)
              : SelectableText(
                  creds.password,
                  textDirection: TextDirection.ltr,
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPassword() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      if (!await _confirm(l10n.deviceLockReason)) {
        _toast(l10n.deviceLockFailed);
        return;
      }
      if (!mounted) return;
      final password = await _askNewPassword(l10n);
      if (password == null) return;
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      final store = ref.read(biometricAuthStoreProvider);
      final existing = await store.credentialsFor(widget.userId);
      if (existing != null) {
        await store.saveCredentials(
          userId: widget.userId,
          identifier: existing.identifier,
          password: password,
        );
      }
      _toast(l10n.loginPasswordSaved);
    } catch (_) {
      _toast(l10n.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeEmail() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      if (!await _confirm(l10n.deviceLockReason)) {
        _toast(l10n.deviceLockFailed);
        return;
      }
      if (!mounted) return;
      final email = await _askNewEmail(l10n);
      if (email == null) return;
      // GoTrue mails a link to the NEW address; auth email (and, via 468,
      // public.users.email) changes only after that link is opened.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: email),
      );
      _toast(l10n.emailChangeSent);
    } catch (_) {
      _toast(l10n.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askNewEmail(AppLocalizations l10n) {
    final email = TextEditingController();
    final key = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.changeEmail),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.changeEmailHint),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l10n.newEmailLabel),
                validator: (v) => AppValidators.email(v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.of(ctx).pop(email.text.trim());
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<String?> _askNewPassword(AppLocalizations l10n) {
    final password = TextEditingController();
    final confirm = TextEditingController();
    final key = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.setLoginPassword),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.setLoginPasswordHint),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.newPassword),
                validator: (v) => AppValidators.password(v),
              ),
              TextFormField(
                controller: confirm,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.confirmPassword),
                validator: (v) =>
                    AppValidators.confirmPassword(v, password.text),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.of(ctx).pop(password.text);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.loginSecurityTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ListTile(
          leading: const Icon(Icons.visibility_outlined),
          title: Text(l10n.showSavedPassword),
          onTap: _busy ? null : _showSaved,
        ),
        ListTile(
          leading: const Icon(Icons.alternate_email_rounded),
          title: Text(l10n.changeEmail),
          onTap: _busy ? null : _changeEmail,
        ),
        ListTile(
          leading: const Icon(Icons.password_rounded),
          title: Text(l10n.setLoginPassword),
          onTap: _busy ? null : _setPassword,
        ),
      ],
    );
  }
}
