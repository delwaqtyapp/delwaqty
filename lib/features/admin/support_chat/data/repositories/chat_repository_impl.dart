import 'dart:typed_data';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';
import 'package:delwaqty/features/admin/support_chat/domain/repositories/chat_repository.dart';
import 'package:delwaqty/features/admin/support_chat/data/datasources/remote/supabase_chat_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {

  ChatRepositoryImpl(this._dataSource);
  final SupabaseChatDataSource _dataSource;

  @override
  Future<List<ChatRoom>> getMyRooms(String userId) {
    return _dataSource.getRoomsForParticipant(userId);
  }

  @override
  Future<List<ChatRoom>> getRoomsForParticipant(String userId) {
    return _dataSource.getRoomsForParticipant(userId);
  }

  @override
  Future<List<ChatRoom>> getActiveRooms() {
    return _dataSource.getActiveRooms();
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
  Future<void> deleteChatRoom(String roomId) {
    return _dataSource.deleteChatRoom(roomId);
  }

  @override
  Future<int> purgeExpiredChats() {
    return _dataSource.purgeExpiredChats();
  }

  @override
  Future<void> setTyping({
    required String roomId,
    required String userId,
    required bool isTyping,
  }) {
    return _dataSource.setTyping(
      roomId: roomId,
      userId: userId,
      isTyping: isTyping,
    );
  }

  @override
  Stream<bool> typingStream(String roomId) {
    return _dataSource.typingStream(roomId);
  }

  @override
  Future<Map<String, dynamic>> getRoomUser(String userId) {
    return _dataSource.getRoomUser(userId);
  }

  @override
  Future<String> uploadAttachment({
    required String roomId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) {
    return _dataSource.uploadAttachment(
      roomId: roomId,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }

  @override
  Future<String> signedUrl(String path) {
    return _dataSource.signedUrl(path);
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
  Future<void> setAssignedAdmin({
    required String roomId,
    required String adminId,
    required String welcomeMessage,
  }) {
    return _dataSource.setAssignedAdmin(
      roomId: roomId,
      adminId: adminId,
      welcomeMessage: welcomeMessage,
    );
  }

  @override
  Stream<ChatMessage> messageStream(String roomId) {
    return _dataSource.messageStream(roomId);
  }
}
