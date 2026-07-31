import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/service_audio_logs/presentation/pages/service_audio_logs_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ServiceAudioLogsModule extends FeatureModule {
  @override
  String get id => 'service_audio_logs';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).serviceAudioLogs;

  @override
  IconData? get icon => Icons.mic_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 86;

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/service-audio-logs',
      builder: (context, state) => const ServiceAudioLogsPage(),
    ),
  ];

  @override
  List<DrawerEntry> get drawerEntries => [
    DrawerEntry(
      id: 'service-audio-logs',
      label: (ctx) => AppLocalizations.of(ctx).serviceAudioLogs,
      icon: Icons.mic_rounded,
      onTap: (ctx, ref) => ctx.push('/service-audio-logs'),
    ),
  ];
}
