import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';

class SupabaseChatDataSource {

  SupabaseChatDataSource(this._client);
  final SupabaseClient _client;

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
    final payload = Map<String, dynamic>.from(room.toJson());
    if (payload['id'] == null || (payload['id'] as String).isEmpty) {
      payload.remove('id');
    }
    final row = await _client.from('chat_rooms').insert(payload).select().single();
    return ChatRoom.fromJson(row);
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
    final payload = Map<String, dynamic>.from(message.toJson());
    if (payload['id'] == null || (payload['id'] as String).isEmpty) {
      payload.remove('id');
    }
    final row = await _client
        .from('chat_messages')
        .insert(payload)
        .select()
        .single();
    await _client.from('chat_rooms').update({
      'last_message_at': message.createdAt.toIso8601String(),
      'updated_at': message.createdAt.toIso8601String(),
    }).eq('id', message.roomId);
    return ChatMessage.fromJson(row);
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
        .order('created_at')
        .map((rows) => rows
            .reversed
            .map((r) => ChatMessage.fromJson(r))
            .toList())
        .expand((list) => list);
  }
}
