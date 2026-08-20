import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';
import 'package:delwaqty/features/admin/support_chat/domain/repositories/chat_repository.dart';
import 'package:delwaqty/features/admin/support_chat/data/datasources/remote/supabase_chat_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final SupabaseChatDataSource _dataSource;

  ChatRepositoryImpl(this._dataSource);

  @override
  Future<List<ChatRoom>> getMyRooms(String userId) {
    return _dataSource.getRoomsForParticipant(userId);
  }

  @override
  Future<List<ChatRoom>> getAllRooms() {
    return _dataSource.getAllRooms();
  }

  @override
  Future<ChatRoom> createRoom(ChatRoom room) {
    return _dataSource.createRoom(room);
  }

  @override
  Future<ChatRoom> getRoomById(String id) {
    return _dataSource.getRoomById(id);
  }

  @override
  Future<void> closeRoom(String id) {
    return _dataSource.closeRoom(id);
  }

  @override
  Future<List<ChatMessage>> getMessages(String roomId, {int limit = 50}) {
    return _dataSource.getMessages(roomId, limit: limit);
  }

  @override
  Future<ChatMessage> sendMessage(ChatMessage message) {
    return _dataSource.sendMessage(message);
  }

  @override
  Future<void> markAsRead(String messageId) {
    return _dataSource.markAsRead(messageId);
  }

  @override
  Stream<ChatMessage> messageStream(String roomId) {
    return _dataSource.messageStream(roomId);
  }
}
