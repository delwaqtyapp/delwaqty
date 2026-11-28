import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Admin issues a one-time recovery code for a user who forgot the password
/// while WhatsApp verification is off. The server checks admin rights, stores
/// only a hash, limits issues per account and writes an audit row.
class AdminAccountRecoveryPage extends StatefulWidget {
  const AdminAccountRecoveryPage({super.key});

  @override
  State<AdminAccountRecoveryPage> createState() =>
      _AdminAccountRecoveryPageState();
}

class _AdminAccountRecoveryPageState extends State<AdminAccountRecoveryPage> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _code;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final phone = normalizeEgyptPhone(_phone.text);
    if (!isEgyptMobilePhone(phone)) {
      setState(() {
        _code = null;
        _error = l10n.phoneInvalid;
      });
      return;
    }
    setState(() {
      _busy = true;
      _code = null;
      _error = null;
    });
    try {
      final r = await Supabase.instance.client.rpc(
        'admin_issue_recovery_code',
        params: {'p_phone': phone},
      );
      final map = r is Map ? r : const {};
      if (map['ok'] == true && map['code'] is String) {
        if (mounted) setState(() => _code = map['code'] as String);
      } else {
        final reason = map['reason'];
        if (mounted) {
          setState(
            () => _error = reason == 'NO_UNIQUE_ACCOUNT'
                ? l10n.adminRecoveryNoAccount
                : reason == 'TOO_MANY_CODES'
                ? l10n.adminRecoveryTooMany
                : l10n.somethingWentWrong,
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminRecoveryTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.adminRecoveryNote, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.phoneNumber,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _busy ? null : _issue,
            child: Text(l10n.adminRecoveryIssue),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_code != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.adminRecoveryCodeLabel,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              _code!,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
