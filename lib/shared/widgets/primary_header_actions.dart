import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/cart_badge.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/shared/widgets/glass_side_menu.dart';

class PrimaryHeaderActions extends ConsumerStatefulWidget {
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
  ConsumerState<PrimaryHeaderActions> createState() =>
      _PrimaryHeaderActionsState();
}

class _PrimaryHeaderActionsState extends ConsumerState<PrimaryHeaderActions> {
  final GlobalKey _menuKey = GlobalKey();

  void _openMenu() {
    final box = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    final anchor = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    GlassSideMenuController.open(context, ref, anchor: anchor);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isGuest = authState is AuthGuest;
    final unreadCount = isGuest
        ? 0
        : ref.watch(unreadCountProvider).value ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showMenu)
          IconButton(
            key: _menuKey,
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
            onPressed: _openMenu,
          ),
        if (widget.showNotifications)
          IconButton(
            tooltip: 'Notifications',
            onPressed: isGuest
                ? () => context.push('/login')
                : () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: Theme.of(context).colorScheme.error,
              label: unreadCount > 99 ? const Text('99+') : Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        if (widget.showCart)
          CartBadge(onTap: widget.onCartTap ?? () => context.push('/market/cart')),
      ],
    );
  }
}