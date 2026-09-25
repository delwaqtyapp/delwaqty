import 'dart:typed_data';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatRoom>> getMyRooms(String userId);
  Future<List<ChatRoom>> getRoomsForParticipant(String userId);
  Future<List<ChatRoom>> getActiveRooms();
  Future<ChatRoom> createRoom(ChatRoom room);
  Future<ChatRoom> getRoomById(String id);
  Future<void> closeRoom(String id);
  Future<void> deleteChatRoom(String roomId);
  Future<int> purgeExpiredChats();
  Future<void> setTyping({
    required String roomId,
    required String userId,
    required bool isTyping,
  });
  Stream<bool> typingStream(String roomId);
  Future<void> setCallStatus({
    required String messageId,
    required String status,
    String? responderId,
    String? responderType,
  });
  Future<Map<String, dynamic>> getRoomUser(String userId);
  Future<String> uploadAttachment({
    required String roomId,
    required String fileName,
    required Uint8List bytes,
    String contentType,
  });
  Future<String> signedUrl(String path);
  Future<List<ChatMessage>> getMessages(String roomId, {int limit = 50});
  Future<ChatMessage> sendMessage(ChatMessage message);
  Future<void> markAsRead(String messageId);
  Future<void> setAssignedAdmin({
    required String roomId,
    required String adminId,
    required String welcomeMessage,
  });
  Stream<ChatMessage> messageStream(String roomId);
}
