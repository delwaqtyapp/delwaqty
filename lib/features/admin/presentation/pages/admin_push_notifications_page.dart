import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/config/firebase_config.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final adminNotificationTokensProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
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
  final _topicController = TextEditingController(text: 'all');

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  String _buildPayload() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final topic = _topicController.text.trim().isEmpty
        ? 'all'
        : _topicController.text.trim();
    return '''
{
  "message": {
    "topic": "$topic",
    "notification": {
      "title": "$title",
      "body": "$body"
    },
    "data": {
      "type": "announcement",
      "click_action": "FLUTTER_NOTIFICATION_CLICK"
    }
  }
}''';
  }

  Future<void> _copyPayload(AppLocalizations l10n) async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      context.showAppSnackBar(l10n.requiredField);
      return;
    }
    await Clipboard.setData(ClipboardData(text: _buildPayload()));
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
                    Text(
                      l10n.connectedDevices,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    tokensAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, __) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          l10n.error,
                          style: TextStyle(color: cs.error),
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
                      l10n.sendPushGuide,
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
                    TextField(
                      controller: _topicController,
                      decoration: InputDecoration(
                        labelText: l10n.targetTopic,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
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
}
