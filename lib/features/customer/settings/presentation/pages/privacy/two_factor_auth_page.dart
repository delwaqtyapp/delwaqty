import 'package:flutter/material.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class TwoFactorAuthPage extends StatefulWidget {
  const TwoFactorAuthPage({super.key});

  @override
  State<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends State<TwoFactorAuthPage> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.twoFactorAuth),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.shield_outlined),
            title: Text(l10n.enableTwoFactor),
            subtitle: Text(l10n.twoFactorDescription),
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
              context.showAppSnackBar(
                v ? l10n.twoFactorEnabled : l10n.twoFactorDisabled,
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security),
            title: Text(l10n.backupCodes),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: _enabled ? null : Colors.grey,
            ),
            enabled: _enabled,
            onTap: _enabled
                ? () => context.showAppSnackBar(l10n.backupCodesInfo)
                : null,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.smartphone),
            title: Text(l10n.authenticatorApp),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: _enabled ? null : Colors.grey,
            ),
            enabled: _enabled,
            onTap: _enabled
                ? () => context.showAppSnackBar(l10n.authenticatorSetup)
                : null,
          ),
        ],
      ),
    );
  }
}
