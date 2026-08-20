import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/_shared/campaigns/data/datasources/remote/supabase_campaign_data_source.dart';
import 'package:delwaqty/features/_shared/campaigns/data/repositories/supabase_campaign_repository_impl.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';

class MockCampaignDataSource extends Mock implements SupabaseCampaignDataSource {}

void main() {
  late MockCampaignDataSource mockDataSource;
  late SupabaseCampaignRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockCampaignDataSource();
    repository = SupabaseCampaignRepositoryImpl(mockDataSource);
  });

  group('SupabaseCampaignRepositoryImpl.getById', () {
    test('returns the campaign for the given id', () async {
      const campaign = Campaign(
        id: 'c1',
        code: 'CODE',
        campaignType: CampaignType.offer,
        nameAr: 'Ø¹Ø±Ø¶',
        status: CampaignStatus.published,
      );
      when(() => mockDataSource.getById('c1')).thenAnswer((_) async => campaign);

      final result = await repository.getById('c1');

      expect(result, campaign);
      verify(() => mockDataSource.getById('c1')).called(1);
    });

    test('returns null when no campaign exists', () async {
      when(() => mockDataSource.getById('missing')).thenAnswer((_) async => null);

      final result = await repository.getById('missing');

      expect(result, isNull);
    });

    test('wraps data source errors in ServerException', () async {
      when(() => mockDataSource.getById(any())).thenThrow(
        Exception('network error'),
      );

      expect(
        () => repository.getById('c1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('SupabaseCampaignRepositoryImpl.getActiveCampaigns', () {
    test('returns campaigns for the given locale', () async {
      const campaign = Campaign(
        id: 'c1',
        code: 'CODE',
        campaignType: CampaignType.coupon,
        nameAr: 'ÙƒÙˆØ¨ÙˆÙ†',
        status: CampaignStatus.published,
        priority: CampaignPriority.critical,
      );
      when(
        () => mockDataSource.getActiveCampaigns(locale: 'ar'),
      ).thenAnswer((_) async => [campaign]);

      final result = await repository.getActiveCampaigns(locale: 'ar');

      expect(result, [campaign]);
      verify(() => mockDataSource.getActiveCampaigns(locale: 'ar')).called(1);
    });

    test('returns an empty list when nothing is active', () async {
      when(
        () => mockDataSource.getActiveCampaigns(locale: 'en'),
      ).thenAnswer((_) async => const <Campaign>[]);

      final result = await repository.getActiveCampaigns(locale: 'en');

      expect(result, isEmpty);
    });

    test('wraps data source errors in ServerException', () async {
      when(() => mockDataSource.getActiveCampaigns(locale: any(named: 'locale')))
          .thenThrow(Exception('network error'));

      expect(
        () => repository.getActiveCampaigns(locale: 'ar'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('SupabaseCampaignRepositoryImpl.getMediaUrl', () {
    test('returns null when the path is null', () async {
      when(() => mockDataSource.getMediaUrl(null)).thenAnswer((_) async => null);

      final result = await repository.getMediaUrl(null);

      expect(result, isNull);
    });

    test('returns the resolved url for a path', () async {
      when(
        () => mockDataSource.getMediaUrl('campaigns/x/b.png'),
      ).thenAnswer((_) async => 'https://cdn.example/b.png');

      final result = await repository.getMediaUrl('campaigns/x/b.png');

      expect(result, 'https://cdn.example/b.png');
    });

    test('wraps data source errors in ServerException', () async {
      when(() => mockDataSource.getMediaUrl(any())).thenThrow(
        Exception('network error'),
      );

      expect(
        () => repository.getMediaUrl('campaigns/x/b.png'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
