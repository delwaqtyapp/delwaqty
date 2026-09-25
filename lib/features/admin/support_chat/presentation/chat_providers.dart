import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';
import 'package:delwaqty/features/admin/support_chat/domain/repositories/chat_repository.dart';
import 'package:delwaqty/features/admin/support_chat/data/datasources/remote/supabase_chat_data_source.dart';
import 'package:delwaqty/features/admin/support_chat/data/repositories/chat_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';

final supabaseChatDataSourceProvider = Provider<SupabaseChatDataSource>((ref) {
  return SupabaseChatDataSource(Supabase.instance.client);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.read(supabaseChatDataSourceProvider));
});

// Admin sees all active rooms across all types
final adminAllRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
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

// All messages for a room
final chatMessagesProvider = FutureProvider.family<List<ChatMessage>, String>((ref, roomId) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getMessages(roomId);
});

// Message stream for a room
final chatMessageStreamProvider = StreamProvider.family<ChatMessage, String>((ref, roomId) {
  final repo = ref.read(chatRepositoryProvider);
  return repo.messageStream(roomId);
});

// Single room lookup (for closed/active state, assigned admin, etc.)
final chatRoomProvider = FutureProvider.family<ChatRoom, String>((ref, roomId) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getRoomById(roomId);
});

// New chat room creation - returns room ID