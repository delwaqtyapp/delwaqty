import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  bool _rideUpdates = true;
  bool _deliveryUpdates = true;
  bool _promotions = false;
  bool _securityAlerts = true;
  bool _chatMessages = true;

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
            secondary: const Icon(Icons.directions_car_outlined),
            title: Text(l10n.rideUpdates),
            subtitle: Text(l10n.rideUpdatesDescription),
            value: _rideUpdates,
            onChanged: (v) => setState(() => _rideUpdates = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.local_shipping_outlined),
            title: Text(l10n.deliveryUpdates),
            subtitle: Text(l10n.deliveryUpdatesDescription),
            value: _deliveryUpdates,
            onChanged: (v) => setState(() => _deliveryUpdates = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.chat_outlined),
            title: Text(l10n.chatMessages),
            subtitle: Text(l10n.chatMessagesDescription),
            value: _chatMessages,
            onChanged: (v) => setState(() => _chatMessages = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.campaign_outlined),
            title: Text(l10n.promotions),
            subtitle: Text(l10n.promotionsDescription),
            value: _promotions,
            onChanged: (v) => setState(() => _promotions = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.shield_outlined),
            title: Text(l10n.securityAlerts),
            subtitle: Text(l10n.securityAlertsDescription),
            value: _securityAlerts,
            onChanged: (v) => setState(() => _securityAlerts = v),
          ),
        ],
      ),
    );
  }
}
