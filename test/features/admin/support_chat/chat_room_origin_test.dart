import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_origin_helpers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

void main() {
  ChatRoom roomWith({
    String? originType,
    String? originLabel,
  }) {
    return ChatRoom(
      id: 'r1',
      roomType: 'support',
      participantIds: const ['u1', 'u2'],
      originType: originType ?? 'customer',
      originLabel: originLabel,
      createdAt: DateTime.parse('2026-09-26T12:00:00Z'),
    );
  }

  group('ChatRoom origin fields', () {
    test('parses origin_type and origin_label from JSON', () {
      final room = ChatRoom.fromJson({
        'id': 'r1',
        'room_type': 'support',
        'participant_ids': ['u1'],
        'origin_type': 'provider',
        'origin_label': 'doctor',
        'created_at': '2026-09-26T12:00:00Z',
        'is_active': true,
      });
      expect(room.originType, 'provider');
      expect(room.originLabel, 'doctor');
    });

    test('defaults to customer when origin_type absent', () {
      final room = ChatRoom.fromJson({
        'id': 'r1',
        'room_type': 'support',
        'participant_ids': ['u1'],
        'created_at': '2026-09-26T12:00:00Z',
        'is_active': true,
      });
      expect(room.originType, 'customer');
      expect(room.originLabel, isNull);
    });

    test('server-authoritative origin never sent on insert payload', () {
      final room = roomWith(originType: 'driver');
      final payload = room.toJson();
      expect(payload.containsKey('origin_type'), isFalse);
      expect(payload.containsKey('origin_label'), isFalse);
    });
  });

  group('chatOriginLabel', () {
    AppLocalizations l10n() {
      return lookupAppLocalizations(const Locale('en'));
    }

    test('maps customer / driver / admin origins', () {
      final l = l10n();
      expect(chatOriginLabel(l, roomWith(originType: 'customer')), l.chatOriginCustomer);
      expect(chatOriginLabel(l, roomWith(originType: 'driver')), l.chatOriginDriver);
      expect(chatOriginLabel(l, roomWith(originType: 'admin')), l.chatOriginAdmin);
    });

    test('provider origin shows service type when label maps', () {
      final l = l10n();
      final label = chatOriginLabel(l, roomWith(originType: 'provider', originLabel: 'doctor'));
      expect(label, contains(l.chatOriginProvider));
      expect(label, contains(l.serviceCategoryDoctor));
    });

    test('provider origin falls back to raw label for unknown types', () {
      final l = l10n();
      final label = chatOriginLabel(l, roomWith(originType: 'provider', originLabel: 'home_services'));
      expect(label, contains('home_services'));
    });
  });
}