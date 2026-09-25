import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
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
    final roomsAsync = ref.watch(adminAllRoomsProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isOwner = user?.role == 'owner';

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
              final refNum = room.referenceNumber;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedFadeIn(
                  child: GlassCard(
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
                      title: Text(
                        refNum == null ? '${l10n.chatRoom} ${room.id.substring(0, 8)}' : '${l10n.complaintNo}: $refNum',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${room.roomType} · ${room.participantIds.length} ${l10n.participants}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (room.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(l10n.active, style: const TextStyle(fontSize: 11, color: Colors.green)),
                            ),
                          if (isOwner)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              tooltip: l10n.deleteChat,
                              onPressed: () => _confirmDelete(room.id),
                            ),
                        ],
                      ),
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

  Future<void> _confirmDelete(String roomId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteChatConfirmTitle),
        content: Text(l10n.deleteChatConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteChat),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(chatRepositoryProvider);
    try {
      await repo.deleteChatRoom(roomId);
      ref.invalidate(adminAllRoomsProvider);
    } catch (e) {
      if (!mounted) return;
      final errorCode = AppLocalizations.of(context).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorCode: $e')),
      );
    }
  }
}