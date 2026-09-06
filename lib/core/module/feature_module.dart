import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

enum DrawerPosition { header, body, settings, footer }

enum ModuleCapability {
  searchable,
  hasNotifications,
  hasLocation,
  hasPayments,
  hasAI,
  hasOfflineMode,
  hasDeepLinks,
  requiresMap,
  requiresPayments,
  requiresDelivery,
  requiresChat,
  requiresWallet,
}

class DrawerEntry {
  const DrawerEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.position = DrawerPosition.body,
    this.badgeStream,
  });

  final String id;
  final String Function(BuildContext) label;
  final IconData icon;
  final void Function(BuildContext, WidgetRef) onTap;
  final DrawerPosition position;
  final Stream<int>? Function(Ref)? badgeStream;
}

abstract class FeatureModule {
  String get id;

  String name(BuildContext context);

  IconData? get icon;

  bool get isNavModule;

  int get navPriority;

  List<RouteBase> get standaloneRoutes => [];

  StatefulShellBranch? buildBranch() => null;

  List<RouteBase> get shellSubRoutes => [];

  List<DrawerEntry> get drawerEntries => [];

  List<Override> providerOverrides(Ref ref) => [];

  Future<void> onRegister() async {}

  Future<void> onActivate() async {}

  Future<void> onDeactivate() async {}

  List<String> get dependsOn => [];

  Set<ModuleCapability> get capabilities => {};

  Stream<int>? badgeStream(Ref ref) => null;
}
