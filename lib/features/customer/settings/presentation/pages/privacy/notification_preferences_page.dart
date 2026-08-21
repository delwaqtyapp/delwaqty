import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  late final SharedPreferences _prefs;
  bool _deliveryUpdates = true;
  bool _promotions = false;
  bool _securityAlerts = true;
  bool _chatMessages = true;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _deliveryUpdates = _prefs.getBool(StorageKeys.deliveryUpdates) ?? true;
    _promotions = _prefs.getBool(StorageKeys.promotions) ?? false;
    _securityAlerts = _prefs.getBool(StorageKeys.securityAlerts) ?? true;
    _chatMessages = _prefs.getBool(StorageKeys.chatMessages) ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationPreferences),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.local_shipping_outlined),
            title: Text(l10n.deliveryUpdates),
            subtitle: Text(l10n.deliveryUpdatesDescription),
            value: _deliveryUpdates,
            onChanged: (v) async {
              setState(() => _deliveryUpdates = v);
              await _prefs.setBool(StorageKeys.deliveryUpdates, v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.chat_outlined),
            title: Text(l10n.chatMessages),
            subtitle: Text(l10n.chatMessagesDescription),
            value: _chatMessages,
            onChanged: (v) async {
              setState(() => _chatMessages = v);
              await _prefs.setBool(StorageKeys.chatMessages, v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.campaign_outlined),
            title: Text(l10n.promotions),
            subtitle: Text(l10n.promotionsDescription),
            value: _promotions,
            onChanged: (v) async {
              setState(() => _promotions = v);
              await _prefs.setBool(StorageKeys.promotions, v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.shield_outlined),
            title: Text(l10n.securityAlerts),
            subtitle: Text(l10n.securityAlertsDescription),
            value: _securityAlerts,
            onChanged: (v) async {
              setState(() => _securityAlerts = v);
              await _prefs.setBool(StorageKeys.securityAlerts, v);
            },
          ),
        ],
      ),
    );
  }
}