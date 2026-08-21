import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminSupportChatPage extends ConsumerStatefulWidget {
  const AdminSupportChatPage({super.key});

  @override
  ConsumerState<AdminSupportChatPage> createState() => _AdminSupportChatPageState();
}

class _AdminSupportChatPageState extends ConsumerState<AdminSupportChatPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportChat)),
      body: roomsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: e.toString(),
        ),
        data: (rooms) {
          if (rooms.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.chat_outlined,
              title: l10n.noChatRooms,
              message: l10n.noChatRoomsDescription,
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
                          color: room.isActive ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: room.isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                      title: Text('${l10n.chatRoom} ${room.id.substring(0, 8)}', maxLines: 1),
                      subtitle: Text('${room.roomType} Â· ${room.participantIds.length} ${l10n.participants}'),
                      trailing: room.isActive
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(l10n.active, style: const TextStyle(fontSize: 11, color: Colors.green)),
                            )
                          : null,
                      onTap: () => context.push('/admin/support-chat/room/${room.id}'),
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
}
