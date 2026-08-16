import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/campaigns/data/datasources/remote/supabase_campaign_data_source.dart';
import 'package:delwaqty/features/campaigns/data/repositories/supabase_campaign_repository_impl.dart';
import 'package:delwaqty/features/campaigns/domain/entities/campaign.dart';

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
        nameAr: 'عرض',
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
}
