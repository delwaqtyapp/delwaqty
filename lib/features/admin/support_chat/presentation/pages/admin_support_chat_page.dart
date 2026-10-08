import 'package:delwaqty/core/utils/avatar_initial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_origin_helpers.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/admin/member_management/presentation/member_providers.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'dart:async';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supportChat),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_user_rounded),
            tooltip: l10n.chatPermissions,
            onPressed: () => context.push('/admin/chat-permissions'),
          ),
        ],
      ),
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${room.roomType} · ${room.participantIds.length} ${l10n.participants}'),
                          const SizedBox(height: 4),
                          _originBadge(room, l10n),
                        ],
                      ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewChat,
        icon: const Icon(Icons.add_comment_rounded),
        label: Text(l10n.newChat),
      ),
    );
  }

  Widget _originBadge(ChatRoom room, AppLocalizations l10n) {
    final (IconData icon, Color color) = switch (room.originType) {
      'driver' => (Icons.local_shipping_outlined, Colors.blue),
      'provider' => (Icons.storefront_outlined, Colors.deepOrange),
      'admin' => (Icons.support_agent_rounded, Colors.teal),
      _ => (Icons.person_outline_rounded, Colors.indigo),
    };
    final label = chatOriginLabel(l10n, room);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Admin-to-anyone: staff start a NEW chat with any member (admin/provider/
  // customer/driver) and the room gets automatically tagged "from admin" by the
  // server. Member search reuses the member-management list filters.
  Future<void> _startNewChat() async {
    final authState = ref.read(authStateProvider);
    final me = authState is AuthAuthenticated ? authState.user : null;
    if (me == null) return;
    final l10n = AppLocalizations.of(context);

    final selected = await _pickMember();
    if (selected == null || !mounted) return;
    if (selected.id == me.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.error)),
      );
      return;
    }

    final room = ChatRoom(
      id: '',
      roomType: 'support',
      participantIds: [me.id, selected.id],
      createdAt: DateTime.now(),
    );
    final repo = ref.read(chatRepositoryProvider);
    try {
      final created = await repo.createRoom(room);
      ref.invalidate(adminAllRoomsProvider);
      if (!mounted) return;
      unawaited(context.push('/admin/support-chat/room/${created.id}'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.error}: $e')),
      );
    }
  }

  // Bottom-sheet member picker for starting an admin-initiated chat.
  Future<Member?> _pickMember() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    String? roleFilter;
    Member? selected;

    await showModalBottomSheet<Member>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Consumer(
          builder: (context, ref, _) {
            final notifier = ref.read(memberOpsProvider.notifier);
            final members = ref.watch(memberOpsProvider);
            // Map the DB role family onto the 4 chat-origin kinds.
            final filtered = members
                .where((m) => _roleMatches(r: m.role, f: roleFilter))
                .toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.selectRecipient,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  onChanged: (q) {
                    notifier.setFilters({
                      'search': q,
                      'role': null,
                      'sort': 'newest',
                      'limit': 100,
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '${l10n.search}…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['admin', 'provider', 'driver', 'customer']
                      .map((role) => ChoiceChip(
                            label: Text(_roleChipLabel(role, l10n)),
                            selected: roleFilter == role,
                            onSelected: (sel) {
                              setState(() => roleFilter = sel ? role : null);
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.noMembersFound),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: filtered.take(24).map((m) {
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  safeInitialFrom([
                                    m.fullName,
                                    m.username,
                                    m.email,
                                  ]),
                                ),
                              ),
                              title: Text(m.fullName ?? m.username ?? m.email ?? '—'),
                              subtitle: Text(_roleDisplayText(m.role, l10n)),
                              onTap: () => Navigator.of(sheetContext).pop(m),
                            );
                          }).toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    ).then((value) => selected = value);

    controller.dispose();
    return selected;
  }

  bool _roleMatches({String? r, String? f}) {
    if (f == null) return true;
    switch (f) {
      case 'provider':
        return r == 'provider' || r == 'merchant';
      case 'driver':
        return r == 'driver' || r == 'delivery';
      case 'admin':
        return r == 'admin' || r == 'owner';
      default:
        return r == f;
    }
  }

  String _roleChipLabel(String role, AppLocalizations l10n) => switch (role) {
        'driver' => l10n.chatOriginDriver,
        'provider' => l10n.chatOriginProvider,
        'admin' => l10n.chatOriginAdmin,
        _ => l10n.chatOriginCustomer,
      };

  String _roleDisplayText(String? role, AppLocalizations l10n) => switch (role) {
        'driver' || 'delivery' => l10n.chatOriginDriver,
        'provider' || 'merchant' => l10n.chatOriginProvider,
        'admin' || 'owner' => l10n.chatOriginAdmin,
        _ => l10n.customerLabel,
      };

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