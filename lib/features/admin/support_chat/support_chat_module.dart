import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/pages/client_support_page.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/pages/support_chat_room_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SupportChatModule extends FeatureModule {
  @override
  String get id => 'support_chat';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).supportChat;

  @override
  IconData? get icon => Icons.chat_bubble_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 84;

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/support',
      builder: (context, state) => const ClientSupportPage(),
    ),
    GoRoute(
      path: '/support/room/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return SupportChatRoomPage(roomId: roomId);
      },
    ),
  ];
}
