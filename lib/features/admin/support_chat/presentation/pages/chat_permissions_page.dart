import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Chat permissions panel.
///
/// Works in BOTH the customer app and the admin app:
///  * "receive incoming calls" — per-user switch (every user / every app).
///  * calls / voice messages / media for ALL users — global switches,
///    shown (and writable) from the ADMIN app only.
class ChatPermissionsPage extends ConsumerStatefulWidget {
  const ChatPermissionsPage({super.key});

  @override
  ConsumerState<ChatPermissionsPage> createState() =>
      _ChatPermissionsPageState();
}

class _ChatPermissionsPageState extends ConsumerState<ChatPermissionsPage> {
  bool _receiveCalls = true;
  bool _calls = true;
  bool _voice = true;
  bool _media = true;
  bool _loaded = false;
  bool _saving = false;

  String? get _myId {
    final auth = ref.read(authStateProvider);
    return auth is AuthAuthenticated ? auth.user.id : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isAdminPanel = ref.watch(isAdminAppProvider);
    final myId = _myId;

    final permissionsAsync = ref.watch(chatPermissionsProvider);
    final receiveAsync = myId == null
        ? null
        : ref.watch(chatReceiveCallsProvider(myId));

    if (!_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final perms = permissionsAsync.asData?.value;
        final receive = receiveAsync?.asData?.value ?? true;
        if (!mounted) return;
        setState(() {
          _calls = perms?['chat_calls_enabled'] as bool? ?? true;
          _voice = perms?['chat_voice_enabled'] as bool? ?? true;
          _media = perms?['chat_media_enabled'] as bool? ?? true;
          _receiveCalls = receive;
          _loaded = true;
        });
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatPermissions)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1) Per-user receive-calls switch (customer + admin apps).
          Card(
            child: SwitchListTile(
              secondary: Icon(Icons.phone_in_talk_rounded, color: cs.primary),
              title: Text(l10n.receiveIncomingCalls),
              subtitle: Text(l10n.receiveIncomingCallsHint),
              value: _receiveCalls,
              onChanged: myId == null
                  ? null
                  : (v) => _save(toggleReceiveCalls: v),
            ),
          ),
          const SizedBox(height: 16),

          // 2) Global feature flags for ALL users — admin app only.
          if (isAdminPanel) ...[
            Text(
              l10n.chatGlobalPermissions,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary:
                        Icon(Icons.call_rounded, color: cs.primary),
                    title: Text(l10n.chatCallsEnabled),
                    subtitle: Text(l10n.chatCallsEnabledHint),
                    value: _calls,
                    onChanged: (v) => _save(calls: v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary:
                        Icon(Icons.mic_rounded, color: cs.primary),
                    title: Text(l10n.chatVoiceEnabled),
                    subtitle: Text(l10n.chatVoiceEnabledHint),
                    value: _voice,
                    onChanged: (v) => _save(voice: v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(Icons.attach_file_rounded,
                        color: cs.primary),
                    title: Text(l10n.chatMediaEnabled),
                    subtitle: Text(l10n.chatMediaEnabledHint),
                    value: _media,
                    onChanged: (v) => _save(media: v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.chatGlobalPermissionsHint,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save({
    bool? toggleReceiveCalls,
    bool? calls,
    bool? voice,
    bool? media,
  }) async {
    if (_saving) return;
    _saving = true;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(chatRepositoryProvider);
    final myId = _myId;
    try {
      if (toggleReceiveCalls != null && myId != null) {
        await repo.setReceiveCalls(myId, toggleReceiveCalls);
        ref.invalidate(chatReceiveCallsProvider(myId));
        setState(() => _receiveCalls = toggleReceiveCalls);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.chatSaved)),
          );
        }
      }
      if (calls != null || voice != null || media != null) {
        await repo.setChatPermissions(
          calls: calls ?? _calls,
          voice: voice ?? _voice,
          media: media ?? _media,
        );
        setState(() {
          if (calls != null) _calls = calls;
          if (voice != null) _voice = voice;
          if (media != null) _media = media;
        });
        ref.invalidate(chatPermissionsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.chatSaved)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      _saving = false;
    }
  }
}