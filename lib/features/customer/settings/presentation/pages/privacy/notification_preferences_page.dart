import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
    final cs = context.colorScheme;

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
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.notificationPreferences,
                              style: context.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.privacy,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Material(
                  color: cs.surfaceContainerLowest,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        context,
                        icon: Icons.local_shipping_outlined,
                        title: l10n.deliveryUpdates,
                        subtitle: l10n.deliveryUpdatesDescription,
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
                      _buildDivider(cs),
                      _buildSwitchTile(
                        context,
                        icon: Icons.chat_outlined,
                        title: l10n.chatMessages,
                        subtitle: l10n.chatMessagesDescription,
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
                      _buildDivider(cs),
                      _buildSwitchTile(
                        context,
                        icon: Icons.campaign_outlined,
                        title: l10n.promotions,
                        subtitle: l10n.promotionsDescription,
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
                      _buildDivider(cs),
                      _buildSwitchTile(
                        context,
                        icon: Icons.shield_outlined,
                        title: l10n.securityAlerts,
                        subtitle: l10n.securityAlertsDescription,
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
                ),
              ],
            ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = context.colorScheme;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(
        title,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: context.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildDivider(ColorScheme cs) {
    return Divider(
      height: 1,
      indent: 66,
      endIndent: 16,
      color: cs.outlineVariant.withValues(alpha: 0.35),
    );
  }
}
