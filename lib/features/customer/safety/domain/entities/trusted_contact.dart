import 'package:freezed_annotation/freezed_annotation.dart';

part 'trusted_contact.freezed.dart';
part 'trusted_contact.g.dart';

enum ContactRelationship { family, friend, colleague, other }

enum NotificationPreference { sms, call, push, both }

@freezed
class TrustedContact with _$TrustedContact {
  const factory TrustedContact({
    required String id,
    required String userId,
    required String name,
    required String phone,
    String? email,
    ContactRelationship? relationship,
    @Default(true) bool notifyOnRide,
    @Default(NotificationPreference.both) NotificationPreference notificationPreference,
    required DateTime createdAt,
  }) = _TrustedContact;

  factory TrustedContact.fromJson(Map<String, dynamic> json) =>
      _$TrustedContactFromJson(json);
}
