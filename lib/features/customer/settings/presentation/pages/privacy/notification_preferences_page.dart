import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  SharedPreferences? _prefs;
  bool _loaded = false;
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
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    if (!mounted) return;
    setState(() {
      _deliveryUpdates = prefs.getBool(StorageKeys.deliveryUpdates) ?? true;
      _promotions = prefs.getBool(StorageKeys.promotions) ?? false;
      _securityAlerts = prefs.getBool(StorageKeys.securityAlerts) ?? true;
      _chatMessages = prefs.getBool(StorageKeys.chatMessages) ?? true;
      _loaded = true;
    });
  }

  Future<void> _updatePreference({
    required String key,
    required String topic,
    required bool value,
  }) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    try {
      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }
    } catch (_) {
      // Topic subscription may be unsupported in test/web environments.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationPreferences),
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.local_shipping_outlined),
                  title: Text(l10n.deliveryUpdates),
                  subtitle: Text(l10n.deliveryUpdatesDescription),
                  value: _deliveryUpdates,
                  onChanged: (v) async {
                    setState(() => _deliveryUpdates = v);
                    await _updatePreference(
                      key: StorageKeys.deliveryUpdates,
                      topic: 'delivery_updates',
                      value: v,
                    );
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
                    await _updatePreference(
                      key: StorageKeys.chatMessages,
                      topic: 'chat_messages',
                      value: v,
                    );
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
                    await _updatePreference(
                      key: StorageKeys.promotions,
                      topic: 'promotions',
                      value: v,
                    );
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
                    await _updatePreference(
                      key: StorageKeys.securityAlerts,
                      topic: 'security_alerts',
                      value: v,
                    );
                  },
                ),
              ],
            ),
    );
  }
}