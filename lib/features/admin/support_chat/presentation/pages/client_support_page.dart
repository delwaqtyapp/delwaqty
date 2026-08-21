import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ClientSupportPage extends ConsumerStatefulWidget {
  const ClientSupportPage({super.key});

  @override
  ConsumerState<ClientSupportPage> createState() => _ClientSupportPageState();
}

class _ClientSupportPageState extends ConsumerState<ClientSupportPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.support)),
      body: roomsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: e.toString(),
        ),
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PremiumEmptyState(
                    icon: Icons.support_agent_outlined,
                    title: l10n.noSupportRooms,
                    message: l10n.startSupportChatDescription,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_comment_rounded),
                    label: Text(l10n.startChat),
                    onPressed: _startNewChat,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedFadeIn(
                  child: GlassCard(
                    borderRadius: 16,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.chat_bubble_rounded, color: cs.primary),
                      ),
                      title: Text('${l10n.chatRoom} ${room.id.substring(0, 8)}', maxLines: 1),
                      subtitle: Text(room.roomType),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/support/room/${room.id}'),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _startNewChat() async {
    final authState = ref.read(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    if (user == null) return;

    final room = ChatRoom(
      id: '',
      roomType: 'support',
      participantIds: [user.id],
      createdAt: DateTime.now(),
    );

    final repo = ref.read(chatRepositoryProvider);
    await repo.createRoom(room);
    ref.invalidate(chatRoomsProvider);
  }
}
