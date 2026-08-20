import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';

void main() {
  group('CampaignType', () {
    test('fromDb maps snake_case values', () {
      expect(CampaignType.fromDb('offer'), CampaignType.offer);
      expect(CampaignType.fromDb('promotion'), CampaignType.promotion);
      expect(CampaignType.fromDb('coupon'), CampaignType.coupon);
      expect(
        CampaignType.fromDb('product_promotion'),
        CampaignType.productPromotion,
      );
      expect(
        CampaignType.fromDb('service_promotion'),
        CampaignType.servicePromotion,
      );
      expect(
        CampaignType.fromDb('service_announcement'),
        CampaignType.serviceAnnouncement,
      );
      expect(
        CampaignType.fromDb('important_notice'),
        CampaignType.importantNotice,
      );
      expect(
        CampaignType.fromDb('emergency_notice'),
        CampaignType.emergencyNotice,
      );
      expect(CampaignType.fromDb('safety_notice'), CampaignType.safetyNotice);
    });

    test('fromDb falls back for unknown values', () {
      expect(CampaignType.fromDb('hacker'), CampaignType.announcement);
    });

    test('dbName round-trips', () {
      for (final type in CampaignType.values) {
        expect(CampaignType.fromDb(type.dbName), type);
      }
    });
  });

  group('CampaignStatus', () {
    test('fromDb maps values', () {
      expect(CampaignStatus.fromDb('draft'), CampaignStatus.draft);
      expect(CampaignStatus.fromDb('pending_review'), CampaignStatus.pendingReview);
      expect(CampaignStatus.fromDb('approved'), CampaignStatus.approved);
      expect(CampaignStatus.fromDb('published'), CampaignStatus.published);
      expect(CampaignStatus.fromDb('expired'), CampaignStatus.expired);
    });

    test('dbName round-trips', () {
      for (final status in CampaignStatus.values) {
        expect(CampaignStatus.fromDb(status.dbName), status);
      }
    });
  });

  group('CampaignPriority', () {
    test('fromDb maps values', () {
      expect(CampaignPriority.fromDb('normal'), CampaignPriority.normal);
      expect(CampaignPriority.fromDb('important'), CampaignPriority.important);
      expect(CampaignPriority.fromDb('critical'), CampaignPriority.critical);
      expect(CampaignPriority.fromDb(null), CampaignPriority.normal);
      expect(CampaignPriority.fromDb('unknown'), CampaignPriority.normal);
    });

    test('dbName round-trips', () {
      for (final priority in CampaignPriority.values) {
        expect(CampaignPriority.fromDb(priority.dbName), priority);
      }
    });
  });

  group('CampaignCta', () {
    test('fromJson maps a copy_code cta', () {
      final cta = CampaignCta.fromJson({
        'type': 'copy_code',
        'code': 'DELWAQTY30',
      });

      expect(cta.type, CampaignCtaType.copyCode);
      expect(cta.code, 'DELWAQTY30');
    });

    test('fromJson maps an internal_route cta', () {
      final cta = CampaignCta.fromJson({
        'type': 'internal_route',
        'route': '/rewards',
      });

      expect(cta.type, CampaignCtaType.internalRoute);
      expect(cta.route, '/rewards');
    });

    test('fromJson falls back to none', () {
      final cta = CampaignCta.fromJson(const {'type': 'none'});
      expect(cta.type, CampaignCtaType.none);
    });
  });

  group('Campaign', () {
    test('fromJson maps fields', () {
      final json = {
        'id': 'c1',
        'code': 'SUMMER20',
        'campaign_type': 'offer',
        'name_ar': 'Ø¹Ø±Ø¶ Ø§Ù„ØµÙŠÙ',
        'name_en': 'Summer Offer',
        'status': 'published',
        'starts_at': '2026-08-01T00:00:00.000Z',
        'ends_at': '2026-08-31T00:00:00.000Z',
      };

      final campaign = Campaign.fromJson(json);

      expect(campaign.id, 'c1');
      expect(campaign.code, 'SUMMER20');
      expect(campaign.campaignType, CampaignType.offer);
      expect(campaign.nameAr, 'Ø¹Ø±Ø¶ Ø§Ù„ØµÙŠÙ');
      expect(campaign.nameEn, 'Summer Offer');
      expect(campaign.status, CampaignStatus.published);
      expect(campaign.startsAt, DateTime.parse('2026-08-01T00:00:00.000Z'));
      expect(campaign.endsAt, DateTime.parse('2026-08-31T00:00:00.000Z'));
      expect(campaign.priority, CampaignPriority.normal);
      expect(campaign.imagePath, isNull);
      expect(campaign.cta, isNull);
    });

    test('fromJson maps feed fields', () {
      final json = {
        'id': 'c2',
        'code': 'HOT',
        'campaign_type': 'coupon',
        'name_ar': 'ÙƒÙˆØ¨ÙˆÙ†',
        'status': 'published',
        'priority': 'critical',
        'image_path': 'campaigns/hot/banner.png',
        'cta': {'type': 'copy_code', 'code': 'HOT10'},
      };

      final campaign = Campaign.fromJson(json);

      expect(campaign.priority, CampaignPriority.critical);
      expect(campaign.imagePath, 'campaigns/hot/banner.png');
      expect(campaign.cta?.type, CampaignCtaType.copyCode);
      expect(campaign.cta?.code, 'HOT10');
    });
  });
}
