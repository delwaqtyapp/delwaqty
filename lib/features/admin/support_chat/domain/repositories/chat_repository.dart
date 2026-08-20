import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatRoom>> getMyRooms(String userId);
  Future<List<ChatRoom>> getAllRooms();
  Future<ChatRoom> createRoom(ChatRoom room);
  Future<ChatRoom> getRoomById(String id);
  Future<void> closeRoom(String id);
  Future<List<ChatMessage>> getMessages(String roomId, {int limit = 50});
  Future<ChatMessage> sendMessage(ChatMessage message);
  Future<void> markAsRead(String messageId);
  Stream<ChatMessage> messageStream(String roomId);
}
