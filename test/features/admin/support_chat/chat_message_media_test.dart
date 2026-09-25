import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';

void main() {
  group('ChatMessage media fields', () {
    test('image message round-trips attachmentUrl', () {
      final msg = ChatMessage(
        id: 'm1',
        roomId: 'r1',
        senderId: 'u1',
        senderType: 'admin',
        message: 'Send Image',
        messageType: 'image',
        attachmentUrl: 'r1/123_img.png',
        isFromAdmin: true,
        createdAt: DateTime.parse('2026-09-25T21:00:00Z'),
      );
      final json = msg.toJson();
      expect(json['message_type'], 'image');
      expect(json['attachment_url'], 'r1/123_img.png');
      expect(json['is_from_admin'], isTrue);
      final restored = ChatMessage.fromJson(json);
      expect(restored.messageType, 'image');
      expect(restored.attachmentUrl, 'r1/123_img.png');
      expect(restored.isFromAdmin, isTrue);
    });

    test('video message round-trips fileUrl', () {
      final msg = ChatMessage(
        id: 'm2',
        roomId: 'r1',
        senderId: 'u2',
        senderType: 'customer',
        message: 'Send Video',
        messageType: 'video',
        fileUrl: 'r1/456_vid.mp4',
        createdAt: DateTime.parse('2026-09-25T21:01:00Z'),
      );
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.messageType, 'video');
      expect(restored.fileUrl, 'r1/456_vid.mp4');
    });

    test('audio message round-trips audioUrl', () {
      final msg = ChatMessage(
        id: 'm3',
        roomId: 'r1',
        senderId: 'u1',
        senderType: 'admin',
        message: 'Voice message',
        messageType: 'audio',
        audioUrl: 'r1/789_voice.m4a',
        isFromAdmin: true,
        createdAt: DateTime.parse('2026-09-25T21:02:00Z'),
      );
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.messageType, 'audio');
      expect(restored.audioUrl, 'r1/789_voice.m4a');
    });

    test('call message keeps metaData', () {
      final msg = ChatMessage(
        id: 'm4',
        roomId: 'r1',
        senderId: 'u1',
        senderType: 'admin',
        message: 'Call me',
        messageType: 'call',
        metaData: {'call_type': 'voice', 'requested_by': 'u1'},
        isFromAdmin: true,
        createdAt: DateTime.parse('2026-09-25T21:03:00Z'),
      );
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.messageType, 'call');
      expect(restored.metaData?['call_type'], 'voice');
    });
  });
}