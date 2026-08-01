import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/cart_badge.dart';
import 'package:delwaqty/features/floating_sidebar/floating_sidebar.dart';
import 'package:delwaqty/features/notifications/notifications_module.dart';

class PrimaryHeaderActions extends ConsumerWidget {
  const PrimaryHeaderActions({
    super.key,
    this.showMenu = true,
    this.showNotifications = true,
    this.showCart = false,
    this.onCartTap,
  });

  final bool showMenu;
  final bool showNotifications;
  final bool showCart;
  final VoidCallback? onCartTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isGuest = authState is AuthGuest;
    final unreadCount = isGuest
        ? 0
        : ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMenu)
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: () => FloatingSidebarController.open(context, ref),
          ),
        if (showNotifications)
          IconButton(
            tooltip: 'Notifications',
            onPressed: isGuest
                ? () => context.push('/login')
                : () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: Theme.of(context).colorScheme.error,
              label: unreadCount > 99 ? Text('99+') : Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        if (showCart)
          CartBadge(onTap: onCartTap ?? () => context.push('/market/cart')),
      ],
    );
  }
}
