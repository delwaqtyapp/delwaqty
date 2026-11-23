import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';
import 'package:delwaqty/features/admin/support_chat/domain/repositories/chat_repository.dart';
import 'package:delwaqty/features/admin/support_chat/data/datasources/remote/supabase_chat_data_source.dart';
import 'package:delwaqty/features/admin/support_chat/data/repositories/chat_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/admin/support_chat/services/chat_call_alert_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/services/realtime/realtime_service.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

final supabaseChatDataSourceProvider = Provider<SupabaseChatDataSource>((ref) {
  return SupabaseChatDataSource(ref.watch(supabaseClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.read(supabaseChatDataSourceProvider));
});

// Global chat feature flags (admin panel): calls / voice / media for ALL users.
final chatPermissionsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getChatPermissions();
});

// Per-user "receive incoming calls" switch (customer + admin apps).
final chatReceiveCallsProvider = FutureProvider.family<bool, String>((
  ref,
  userId,
) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.canReceiveCalls(userId);
});

// App-wide incoming-call alert notification (fires even when the room screen
// isn't open). Listens on chat_messages INSERT with message_type='call'.
final chatCallAlertServiceProvider = Provider<ChatCallAlertService>((ref) {
  final service = ChatCallAlertService(
    ref,
    ref.watch(realtimeServiceProvider),
    ref.watch(loggerProvider),
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

// Admin sees all active rooms across all types
final adminAllRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
  // 376: purge moved to the nightly purge-expired-chats cron (owner/service
  // only); screen loads no longer trigger it.
  // Admins see all active rooms
  return repo.getActiveRooms();
});

// Provider sees their own rooms
final providerMyRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
  return repo.getRoomsForParticipant(user.id);
});

// Driver sees their own rooms
final driverMyRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
  return repo.getRoomsForParticipant(user.id);
});

// Customer sees their own rooms
final customerMyRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
  return repo.getRoomsForParticipant(user.id);
});

// All messages for a room (realtime stream; no loading flicker on send).
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  roomId,
) {
  final repo = ref.read(chatRepositoryProvider);
  return repo.messageStream(roomId);
});

// Single room lookup (for closed/active state, assigned admin, etc.)
final chatRoomProvider = FutureProvider.family<ChatRoom, String>((
  ref,
  roomId,
) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getRoomById(roomId);
});

// LIVE room stream: reflects is_active / assigned_admin changes in real time
// on BOTH sides (admin closing the chat flips the customer's UI instantly).
// UPDATE events always carry the new record, so REPLICA IDENTITY DEFAULT
// suffices (422); the old FULL requirement from migration 098 no longer holds.
final chatRoomStreamProvider = StreamProvider.family<ChatRoom, String>((
  ref,
  roomId,
) {
  return ref
      .watch(supabaseClientProvider)
      .from('chat_rooms')
      .stream(primaryKey: ['id'])
      .eq('id', roomId)
      .map((rows) {
        final list = (rows as List).cast<Map<String, dynamic>>();
        if (list.isEmpty) {
          throw StateError('chat room not found: $roomId');
        }
        return ChatRoom.fromJson(list.last);
      });
});

// Whether the peer (non-self participant) is currently typing.
final chatPeerTypingProvider = StreamProvider.family<bool, String>((
  ref,
  roomId,
) {
  final repo = ref.read(chatRepositoryProvider);
  return repo.typingStream(roomId);
});

// Resolves a user's profile (full_name, phone, avatar_url, role) for chat bubbles & room headers.
final chatRoomUserProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
      if (userId.isEmpty) return const <String, dynamic>{};
      final repo = ref.read(chatRepositoryProvider);
      return repo.getRoomUser(userId);
    });
