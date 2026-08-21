import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/customer/safety/domain/repositories/safety_repository.dart';
import 'package:delwaqty/features/customer/safety/data/datasources/remote/supabase_safety_data_source.dart';
import 'package:delwaqty/features/customer/safety/data/repositories/safety_repository_impl.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/trusted_contact.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/sos_alert.dart';

final supabaseSafetyDataSourceProvider = Provider<SupabaseSafetyDataSource>((ref) {
  return SupabaseSafetyDataSource(Supabase.instance.client);
});

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepositoryImpl(ref.read(supabaseSafetyDataSourceProvider));
});

final trustedContactsProvider = StreamProvider<List<TrustedContact>>((ref) {
  return ref.read(safetyRepositoryProvider).watchTrustedContacts();
});

final activeSosAlertsProvider = StreamProvider<List<SosAlert>>((ref) {
  return ref.read(safetyRepositoryProvider).watchActiveSosAlerts();
});
