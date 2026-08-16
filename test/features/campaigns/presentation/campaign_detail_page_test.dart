import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/features/campaigns/presentation/campaign_providers.dart';
import 'package:delwaqty/features/campaigns/presentation/pages/campaign_detail_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

void main() {
  testWidgets('renders campaign name, dates and description', (tester) async {
    final campaign = Campaign(
      id: 'c1',
      code: 'SUMMER20',
      campaignType: CampaignType.offer,
      nameAr: 'عرض الصيف',
      nameEn: 'Summer Offer',
      subtitleAr: 'خصم 20%',
      descriptionAr: 'خصم يصل إلى 20% على جميع الطلبات',
      status: CampaignStatus.published,
      startsAt: DateTime(2026, 8),
      endsAt: DateTime(2026, 8, 31),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          campaignByIdProvider.overrideWith((ref, id) async => campaign),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: CampaignDetailPage(campaignId: 'c1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('عرض الصيف'), findsOneWidget);
    expect(find.text('1/8/2026 - 31/8/2026'), findsOneWidget);
    expect(find.text('خصم يصل إلى 20% على جميع الطلبات'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
  });

  testWidgets('shows not-found when the campaign is null', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          campaignByIdProvider.overrideWith((ref, id) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: CampaignDetailPage(campaignId: 'missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Campaign not found'), findsOneWidget);
  });

  testWidgets('shows not-found when the provider throws', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          campaignByIdProvider.overrideWith(
            (ref, id) async => throw Exception('boom'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: CampaignDetailPage(campaignId: 'c1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Campaign not found'), findsOneWidget);
  });
}
