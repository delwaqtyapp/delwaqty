import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/data/datasources/remote/supabase_notification_data_source.dart';
import 'package:delwaqty/data/repositories/supabase_notification_repository_impl.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';

class MockNotificationDataSource extends Mock
    implements SupabaseNotificationDataSource {}

void main() {
  late MockNotificationDataSource mockDataSource;
  late SupabaseNotificationRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockNotificationDataSource();
    repository = SupabaseNotificationRepositoryImpl(mockDataSource);
  });

  group('SupabaseNotificationRepositoryImpl.deactivateDeviceTokens', () {
    test('delegates the device id to the data source', () async {
      when(() => mockDataSource.deactivateDeviceTokens('dev-1')).thenAnswer(
        (_) async {},
      );

      await repository.deactivateDeviceTokens('dev-1');

      verify(() => mockDataSource.deactivateDeviceTokens('dev-1')).called(1);
    });

    test('wraps data source errors in ServerException', () async {
      when(() => mockDataSource.deactivateDeviceTokens(any())).thenThrow(
        Exception('network error'),
      );

      expect(
        () => repository.deactivateDeviceTokens('dev-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('SupabaseNotificationRepositoryImpl.getNotifications', () {
    test('delegates pagination params to the data source', () async {
      when(
        () => mockDataSource.getNotifications(
          unreadOnly: any(named: 'unreadOnly'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => <AppNotification>[]);

      await repository.getNotifications(limit: 10, offset: 20);

      verify(
        () => mockDataSource.getNotifications(
          unreadOnly: any(named: 'unreadOnly'),
          limit: 10,
          offset: 20,
        ),
      ).called(1);
    });
  });
}
