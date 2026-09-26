import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';

class AppLifecycleCategoryRefresh extends ConsumerStatefulWidget {
  const AppLifecycleCategoryRefresh({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleCategoryRefresh> createState() =>
      _AppLifecycleCategoryRefreshState();
}

class _AppLifecycleCategoryRefreshState
    extends ConsumerState<AppLifecycleCategoryRefresh> {
  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => ref.invalidate(activeCategoriesProvider),
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}