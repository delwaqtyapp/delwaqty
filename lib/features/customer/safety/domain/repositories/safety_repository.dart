import 'package:delwaqty/features/customer/safety/domain/entities/sos_alert.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/sos_result.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/trusted_contact.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/contact_result.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/live_share_session.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/live_share_result.dart';

abstract class SafetyRepository {
  // SOS
  Future<SosResult> triggerSosAlert(
    String rideId, {
    double? latitude,
    double? longitude,
    String? address,
    SosAlertType alertType = SosAlertType.manual,
  });
  Future<void> resolveSosAlert(String alertId, {SosAlertStatus status});
  Future<List<SosAlert>> getSosAlerts({String? rideId});
  Stream<List<SosAlert>> watchActiveSosAlerts();

  // Trusted Contacts
  Future<List<TrustedContact>> getTrustedContacts();
  Future<ContactResult> upsertTrustedContact(
    String name,
    String phone, {
    String? id,
    String? email,
    ContactRelationship? relationship,
    bool notifyOnRide = true,
    NotificationPreference notificationPreference = NotificationPreference.both,
  });
  Future<void> deleteTrustedContact(String contactId);
  Stream<List<TrustedContact>> watchTrustedContacts();

  // Live Share
  Future<LiveShareResult> startLiveShare(String rideId, {int durationMinutes});
  Future<void> stopLiveShare(String sessionId);
  Future<LiveShareSession?> getActiveLiveShare(String rideId);
}
