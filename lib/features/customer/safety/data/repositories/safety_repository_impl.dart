import 'package:delwaqty/features/customer/safety/domain/repositories/safety_repository.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/sos_alert.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/sos_result.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/trusted_contact.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/contact_result.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/live_share_session.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/live_share_result.dart';
import 'package:delwaqty/features/customer/safety/data/datasources/remote/supabase_safety_data_source.dart';

class SafetyRepositoryImpl implements SafetyRepository {
  final SupabaseSafetyDataSource _dataSource;

  SafetyRepositoryImpl(this._dataSource);

  @override
  Future<SosResult> triggerSosAlert(
    String rideId, {
    double? latitude,
    double? longitude,
    String? address,
    SosAlertType alertType = SosAlertType.manual,
  }) =>
      _dataSource.triggerSosAlert(
        rideId,
        latitude: latitude,
        longitude: longitude,
        address: address,
        alertType: alertType,
      );

  @override
  Future<void> resolveSosAlert(String alertId, {SosAlertStatus status = SosAlertStatus.resolved}) =>
      _dataSource.resolveSosAlert(alertId, status: status);

  @override
  Future<List<SosAlert>> getSosAlerts({String? rideId}) =>
      _dataSource.getSosAlerts(rideId: rideId);

  @override
  Stream<List<SosAlert>> watchActiveSosAlerts() =>
      _dataSource.watchActiveSosAlerts();

  @override
  Future<List<TrustedContact>> getTrustedContacts() =>
      _dataSource.getTrustedContacts();

  @override
  Future<ContactResult> upsertTrustedContact(
    String name,
    String phone, {
    String? id,
    String? email,
    ContactRelationship? relationship,
    bool notifyOnRide = true,
    NotificationPreference notificationPreference = NotificationPreference.both,
  }) =>
      _dataSource.upsertTrustedContact(
        name,
        phone,
        id: id,
        email: email,
        relationship: relationship,
        notifyOnRide: notifyOnRide,
        notificationPreference: notificationPreference,
      );

  @override
  Future<void> deleteTrustedContact(String contactId) =>
      _dataSource.deleteTrustedContact(contactId);

  @override
  Stream<List<TrustedContact>> watchTrustedContacts() =>
      _dataSource.watchTrustedContacts();

  @override
  Future<LiveShareResult> startLiveShare(String rideId, {int durationMinutes = 60}) =>
      _dataSource.startLiveShare(rideId, durationMinutes: durationMinutes);

  @override
  Future<void> stopLiveShare(String sessionId) =>
      _dataSource.stopLiveShare(sessionId);

  @override
  Future<LiveShareSession?> getActiveLiveShare(String rideId) =>
      _dataSource.getActiveLiveShare(rideId);
}
