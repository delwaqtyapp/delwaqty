import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';
import 'package:delwaqty/features/admin/support_chat/domain/repositories/chat_repository.dart';
import 'package:delwaqty/features/admin/support_chat/data/datasources/remote/supabase_chat_data_source.dart';
import 'package:delwaqty/features/admin/support_chat/data/repositories/chat_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/core/auth/admin_access.dart';

final supabaseChatDataSourceProvider = Provider<SupabaseChatDataSource>((ref) {
  return SupabaseChatDataSource(Supabase.instance.client);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.read(supabaseChatDataSourceProvider));
});

final chatRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final repo = ref.read(chatRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final user = authState is AuthAuthenticated ? authState.user : null;
  if (user == null) return [];
  if (user.isAdmin) {
    return repo.getAllRooms();
  }
  return repo.getMyRooms(user.id);
});

final chatMessagesProvider = FutureProvider.family<List<ChatMessage>, String>((ref, roomId) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.getMessages(roomId);
});

final chatMessageStreamProvider = StreamProvider.family<ChatMessage, String>((ref, roomId) {
  final repo = ref.read(chatRepositoryProvider);
  return repo.messageStream(roomId);
});
