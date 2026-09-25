import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';

class SupabaseChatDataSource {

  SupabaseChatDataSource(this._client);
  final SupabaseClient _client;
  static const _bucket = 'chat_attachments';

  Future<Map<String, dynamic>> getRoomUser(String userId) async {
    try {
      final row = await _client
          .from('users')
          .select('id,full_name,phone,avatar_url,role')
          .eq('id', userId)
          .maybeSingle();
      return row ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<String> uploadAttachment({
    required String roomId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$roomId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return path;
  }

  Future<String> signedUrl(String path) async {
    final res = await _client.storage.from(_bucket).createSignedUrl(path, 3600);
    return res;
  }

  Future<List<ChatRoom>> getRoomsForParticipant(String userId) async {
    final rows = await _client
        .from('chat_rooms')
        .select()
        .contains('participant_ids', [userId])
        .order('last_message_at', ascending: false);
    return rows.map((r) => ChatRoom.fromJson(r)).toList();
  }

  Future<List<ChatRoom>> getActiveRooms() async {
    final rows = await _client
        .from('chat_rooms')
        .select()
        .eq('is_active', true)
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
    final now = DateTime.now();
    final oneWeekLater = now.add(const Duration(days: 7));
    await _client.from('chat_rooms').update({
      'is_active': false,
      'auto_delete_at': oneWeekLater.toIso8601String(),
      'updated_at': now.toIso8601String(),
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

  Future<void> setAssignedAdmin({
    required String roomId,
    required String adminId,
    required String welcomeMessage,
  }) async {
    await _client.from('chat_rooms').update({
      'assigned_admin_id': adminId,
      'welcome_message': welcomeMessage,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', roomId);
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
