import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/support_chat/domain/entities/chat_message.dart';

class SupabaseChatDataSource {
  final SupabaseClient _client;

  SupabaseChatDataSource(this._client);

  Future<List<ChatRoom>> getRoomsForParticipant(String userId) async {
    final rows = await _client
        .from('chat_rooms')
        .select()
        .contains('participant_ids', [userId])
        .order('last_message_at', ascending: false);
    return rows.map((r) => ChatRoom.fromJson(r)).toList();
  }

  Future<List<ChatRoom>> getAllRooms() async {
    final rows = await _client
        .from('chat_rooms')
        .select()
        .order('last_message_at', ascending: false);
    return rows.map((r) => ChatRoom.fromJson(r)).toList();
  }

  Future<ChatRoom> createRoom(ChatRoom room) async {
    await _client.from('chat_rooms').insert(room.toJson());
    return room;
  }

  Future<ChatRoom> getRoomById(String id) async {
    final row = await _client.from('chat_rooms').select().eq('id', id).single();
    return ChatRoom.fromJson(row);
  }

  Future<void> closeRoom(String id) async {
    await _client.from('chat_rooms').update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<ChatMessage>> getMessages(String roomId, {int limit = 50}) async {
    final rows = await _client
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.reversed.map((r) => ChatMessage.fromJson(r)).toList();
  }

  Future<ChatMessage> sendMessage(ChatMessage message) async {
    await _client.from('chat_messages').insert(message.toJson());
    await _client.from('chat_rooms').update({
      'last_message_at': message.createdAt.toIso8601String(),
      'updated_at': message.createdAt.toIso8601String(),
    }).eq('id', message.roomId);
    return message;
  }

  Future<void> markAsRead(String messageId) async {
    await _client.from('chat_messages').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  Stream<ChatMessage> messageStream(String roomId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .reversed
            .map((r) => ChatMessage.fromJson(r))
            .toList())
        .expand((list) => list);
  }
}
