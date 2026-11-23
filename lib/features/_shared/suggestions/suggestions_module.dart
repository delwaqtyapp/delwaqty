import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/_shared/suggestions/presentation/pages/my_suggestions_page.dart';
import 'package:delwaqty/features/_shared/suggestions/presentation/pages/new_suggestion_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Platform-wide Suggestions module (owner request 2026-11-23): registered in
/// all four flavors so every user can send ideas from the profile menu next to
/// Complaints. The admin triage screen lives in the admin shell at
/// /admin/suggestions (see AdminModule), same pattern as /admin/complaints.
class SuggestionsModule extends FeatureModule {
  @override
  String get id => 'suggestions';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).suggestions;

  @override
  IconData? get icon => Icons.lightbulb_outline_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 82;

  @override
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'my-suggestions',
      label: (ctx) => AppLocalizations.of(ctx).suggestions,
      icon: Icons.lightbulb_outline_rounded,
      onTap: (ctx, ref) {
        ctx.push('/my-suggestions');
      },
    ),
  ];

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/my-suggestions',
      builder: (context, state) => const MySuggestionsPage(),
    ),
    GoRoute(
      path: '/new-suggestion',
      builder: (context, state) => const NewSuggestionPage(),
    ),
  ];
}
