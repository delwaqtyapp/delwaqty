import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/config/firebase_config.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
          .order('updated_at', ascending: false)
          .limit(50);
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
      if (context.mounted) {
        context.showAppSnackBar(l10n.sentToRecipients(sent));
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

  String _buildPayload(AppLocalizations l10n) {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final topic = _audience == 'all' ? 'all' : 'role_$_audience';
    return '''
{
  "message": {
    "topic": "$topic",
    "notification": {
      "title": "$title",
      "body": "$body"
    },
    "data": {
      "type": "${_type.name}",
      "click_action": "FLUTTER_NOTIFICATION_CLICK"
    }
  }
}''';
  }

  Future<void> _copyPayload(AppLocalizations l10n) async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      context.showAppSnackBar(l10n.requiredField, isError: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: _buildPayload(l10n)));
    if (context.mounted) {
      context.showAppSnackBar(l10n.copiedToClipboard);
    }
  }

  Future<void> _openConsoleGuide(AppLocalizations l10n) async {
    final url =
        'https://console.firebase.google.com/project/${FirebaseConfig.projectId}/messaging';
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      context.showAppSnackBar(l10n.copiedToClipboard);
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
                        if (tokens.isEmpty) {
                          return Text(
                            l10n.noData,
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        }
                        return Column(
                          children: [
                            Text(
                              '${tokens.length} ${l10n.connectedDevices}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            for (final token in tokens.take(10))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  token['platform'] == 'android'
                                      ? Icons.phone_android_rounded
                                      : Icons.devices_rounded,
                                  color: cs.primary,
                                ),
                                title: Text(
                                  _maskToken(token['token'] as String? ?? ''),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  _formatTime(
                                    DateTime.tryParse(
                                      token['updated_at'] as String? ?? '',
                                    ),
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
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
          const SizedBox(height: 16),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 150),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firebase',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.sendPushGuide,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => _copyPayload(l10n),
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(l10n.copyCommand),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openConsoleGuide(l10n),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(
                        'console.firebase.google.com/project/${FirebaseConfig.projectId}/messaging',
                      ),
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

  String _maskToken(String token) {
    if (token.length <= 16) return token;
    return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
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

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
