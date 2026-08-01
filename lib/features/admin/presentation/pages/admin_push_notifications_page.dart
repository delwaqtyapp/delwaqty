import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// How long a token is considered "online" since its last update.
/// The app refreshes its token every 5 minutes (heartbeat), so a token
/// not seen for over 15 minutes is treated as offline.
@visibleForTesting
const onlineWindow = Duration(minutes: 15);

/// Splits the registered devices into online / offline counters based on
/// the last time each token was seen (`updated_at`).
@visibleForTesting
({int online, int offline}) computeDeviceStats(
  List<Map<String, dynamic>> tokens,
  DateTime now,
) {
  var online = 0;
  for (final token in tokens) {
    final updated = DateTime.tryParse(token['updated_at'] as String? ?? '');
    if (updated != null &&
        now.difference(updated).inMinutes <= onlineWindow.inMinutes) {
      online++;
    }
  }
  return (online: online, offline: tokens.length - online);
}

@visibleForTesting
Map<String, dynamic> buildBroadcastParams({
  required String title,
  required String body,
  required NotificationType type,
  String? deepLink,
  String audience = 'all',
}) {
  final link = deepLink?.trim() ?? '';
  return {
    'p_title': title,
    'p_body': body,
    'p_type': type.name,
    'p_deep_link': link.isEmpty ? null : link,
    'p_target_role': audience == 'all' ? null : audience,
    'p_target_user_id': null,
  };
}

final adminNotificationTokensProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final client = Supabase.instance.client;
      final data = await client
          .from('notification_tokens')
          .select('token, platform, updated_at')
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    });

class AdminPushNotificationsPage extends ConsumerStatefulWidget {
  const AdminPushNotificationsPage({super.key});

  @override
  ConsumerState<AdminPushNotificationsPage> createState() =>
      _AdminPushNotificationsPageState();
}

class _AdminPushNotificationsPageState
    extends ConsumerState<AdminPushNotificationsPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _deepLinkController = TextEditingController();
  NotificationType _type = NotificationType.info;
  String _audience = 'all';
  bool _sending = false;
  int _lastSentDeviceCount = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification(AppLocalizations l10n) async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      context.showAppSnackBar(l10n.requiredField, isError: true);
      return;
    }

    setState(() => _sending = true);
    try {
      final client = Supabase.instance.client;
      final result = await client.rpc(
        'admin_broadcast_notification',
        params: buildBroadcastParams(
          title: title,
          body: body,
          type: _type,
          deepLink: _deepLinkController.text,
          audience: _audience,
        ),
      );
      final sent = result is num ? result.toInt() : 0;
      setState(() => _lastSentDeviceCount = sent);
      if (context.mounted) {
        context.showAppSnackBar(l10n.sentToDevices(sent));
      }
      ref.invalidate(adminNotificationTokensProvider);
    } catch (e) {
      if (context.mounted) {
        context.showAppSnackBar(l10n.sendFailed, isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tokensAsync = ref.watch(adminNotificationTokensProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pushNotificationsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedFadeIn(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.connectedDevices,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.retry,
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () => ref.invalidate(
                            adminNotificationTokensProvider,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    tokensAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.loadDevicesFailed,
                              style: TextStyle(color: cs.error),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              e.toString(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      data: (tokens) {
                        final stats = computeDeviceStats(
                          tokens,
                          DateTime.now(),
                        );
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _DeviceStatTile(
                                    icon: Icons.cloud_done_rounded,
                                    label: l10n.devicesOnline,
                                    value: stats.online,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DeviceStatTile(
                                    icon: Icons.cloud_off_rounded,
                                    label: l10n.devicesOffline,
                                    value: stats.offline,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => context.showAppSnackBar(
                                l10n.sentToDevices(_lastSentDeviceCount),
                              ),
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                              ),
                              label: Text(
                                '${l10n.devicesReceived}: $_lastSentDeviceCount',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 100),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pushNotificationsTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.broadcastNote,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.notificationTitle,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: l10n.notificationBody,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.notificationType,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<NotificationType>(
                      initialValue: _type,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(_typeIcon(_type)),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: NotificationType.info,
                          child: Text(l10n.typeInfo),
                        ),
                        DropdownMenuItem(
                          value: NotificationType.warning,
                          child: Text(l10n.typeWarning),
                        ),
                        DropdownMenuItem(
                          value: NotificationType.success,
                          child: Text(l10n.typeSuccess),
                        ),
                        DropdownMenuItem(
                          value: NotificationType.reminder,
                          child: Text(l10n.typeReminder),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _type = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _audience,
                      decoration: InputDecoration(
                        labelText: l10n.audience,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(l10n.audienceAll),
                        ),
                        DropdownMenuItem(
                          value: 'customer',
                          child: Text(l10n.audienceCustomer),
                        ),
                        DropdownMenuItem(
                          value: 'driver',
                          child: Text(l10n.audienceDriver),
                        ),
                        DropdownMenuItem(
                          value: 'merchant',
                          child: Text(l10n.audienceMerchant),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(l10n.audienceAdmin),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _audience = value ?? 'all'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _deepLinkController,
                      decoration: InputDecoration(
                        labelText: l10n.deepLink,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _sending
                          ? null
                          : () => _sendNotification(l10n),
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(l10n.sendNotification),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return Icons.info_outline_rounded;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.success:
        return Icons.check_circle_outline_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
    }
  }
}

class _DeviceStatTile extends StatelessWidget {
  const _DeviceStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
