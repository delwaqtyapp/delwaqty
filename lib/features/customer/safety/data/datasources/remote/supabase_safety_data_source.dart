import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/sos_alert.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/sos_result.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/trusted_contact.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/contact_result.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/live_share_session.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/live_share_result.dart';

class SupabaseSafetyDataSource {
  final SupabaseClient _client;

  SupabaseSafetyDataSource(this._client);

  String get _userId => _client.auth.currentUser!.id;

  // --- SOS ---

  Future<SosResult> triggerSosAlert(
    String rideId, {
    double? latitude,
    double? longitude,
    String? address,
    SosAlertType alertType = SosAlertType.manual,
  }) async {
    final data = _checkRpc(await _client.rpc('trigger_sos_alert', params: {
      'p_ride_id': rideId,
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_address': address,
      'p_alert_type': alertType.name,
    }));

    final contacts = (data['notified_contacts'] as List<dynamic>? ?? [])
        .map((c) => NotifiedContact.fromJson(c as Map<String, dynamic>))
        .toList();

    return SosResult(
      success: data['success'] as bool,
      alertId: data['alert_id'] as String,
      notifiedContacts: contacts,
      rideId: data['ride_id'] as String,
    );
  }

  Future<void> resolveSosAlert(String alertId, {SosAlertStatus status = SosAlertStatus.resolved}) async {
    _checkRpc(await _client.rpc('resolve_sos_alert', params: {
      'p_alert_id': alertId,
      'p_status': status.name,
    }));
  }

  Future<List<SosAlert>> getSosAlerts({String? rideId}) async {
    var query = _client.from('sos_alerts').select();
    if (rideId != null) {
      query = query.eq('ride_id', rideId);
    }
    final rows = await query.order('created_at', ascending: false);
    return rows.map(_sosAlertFromRow).toList();
  }

  Stream<List<SosAlert>> watchActiveSosAlerts() {
    return _client
        .from('sos_alerts')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .map((rows) => rows
            .where((r) => r['status'] == 'active')
            .toList()
          ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String)))
        .map((rows) => rows.map(_sosAlertFromRow).toList());
  }

  // --- Trusted Contacts ---

  Future<List<TrustedContact>> getTrustedContacts() async {
    final rows = await _client
        .from('trusted_contacts')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return rows.map(_trustedContactFromRow).toList();
  }

  Future<ContactResult> upsertTrustedContact(
    String name,
    String phone, {
    String? id,
    String? email,
    ContactRelationship? relationship,
    bool notifyOnRide = true,
    NotificationPreference notificationPreference = NotificationPreference.both,
  }) async {
    final data = _checkRpc(await _client.rpc('upsert_trusted_contact', params: {
      'p_contact_id': id,
      'p_name': name,
      'p_phone': phone,
      'p_email': email,
      'p_relationship': relationship?.name,
      'p_notify_on_ride': notifyOnRide,
      'p_notification_preference': notificationPreference.name,
    }));

    return ContactResult(
      success: data['success'] as bool,
      contactId: data['contact_id'] as String?,
      reason: data['reason'] as String?,
    );
  }

  Future<void> deleteTrustedContact(String contactId) async {
    _checkRpc(await _client.rpc('delete_trusted_contact', params: {
      'p_contact_id': contactId,
    }));
  }

  Stream<List<TrustedContact>> watchTrustedContacts() {
    return _client
        .from('trusted_contacts')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_trustedContactFromRow).toList());
  }

  // --- Live Share ---

  Future<LiveShareResult> startLiveShare(String rideId, {int durationMinutes = 60}) async {
    final data = _checkRpc(await _client.rpc('start_live_share', params: {
      'p_ride_id': rideId,
      'p_duration_minutes': durationMinutes,
    }));

    return LiveShareResult(
      success: data['success'] as bool,
      sessionId: data['session_id'] as String,
      shareToken: data['share_token'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String),
    );
  }

  Future<void> stopLiveShare(String sessionId) async {
    _checkRpc(await _client.rpc('stop_live_share', params: {
      'p_session_id': sessionId,
    }));
  }

  Future<LiveShareSession?> getActiveLiveShare(String rideId) async {
    final data = await _client.rpc('get_live_share_session', params: {
      'p_ride_id': rideId,
    });
    if (data == null) return null;
    final map = data as Map<String, dynamic>;
    return LiveShareSession(
      id: map['session_id'] as String,
      rideId: rideId,
      userId: _userId,
      shareToken: map['share_token'] as String,
      isActive: map['is_active'] as bool,
      expiresAt: DateTime.parse(map['expires_at'] as String),
      createdAt: DateTime.now(),
    );
  }

  // --- Helpers ---

  Map<String, dynamic> _checkRpc(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    throw Exception('Unexpected RPC result: $result');
  }

  SosAlert _sosAlertFromRow(Map<String, dynamic> row) {
    return SosAlert(
      id: row['id'] as String,
      rideId: row['ride_id'] as String,
      userId: row['user_id'] as String,
      alertType: SosAlertType.values.firstWhere(
        (e) => e.name == row['alert_type'],
        orElse: () => SosAlertType.manual,
      ),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      address: row['address'] as String?,
      status: SosAlertStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => SosAlertStatus.active,
      ),
      notifiedContactIds: (row['notified_contact_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      notes: row['notes'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      resolvedAt: row['resolved_at'] != null
          ? DateTime.parse(row['resolved_at'] as String)
          : null,
    );
  }

  TrustedContact _trustedContactFromRow(Map<String, dynamic> row) {
    return TrustedContact(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String,
      email: row['email'] as String?,
      relationship: row['relationship'] != null
          ? ContactRelationship.values.firstWhere(
              (e) => e.name == row['relationship'],
              orElse: () => ContactRelationship.other,
            )
          : null,
      notifyOnRide: row['notify_on_ride'] as bool? ?? true,
      notificationPreference: NotificationPreference.values.firstWhere(
        (e) => e.name == row['notification_preference'],
        orElse: () => NotificationPreference.both,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
