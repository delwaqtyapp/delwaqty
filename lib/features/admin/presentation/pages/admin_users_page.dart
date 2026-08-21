import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

String _roleLabel(AdminRole role, AppLocalizations l10n) => switch (role) {
  AdminRole.owner => l10n.roleOwner,
  AdminRole.countryAdmin => l10n.countryAdmin,
  AdminRole.governorateAdmin => l10n.governorateAdmin,
  AdminRole.centerAdmin => l10n.centerAdmin,
  AdminRole.villageAdmin => l10n.villageAdmin,
  AdminRole.admin => l10n.roleAdmin,
};

class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showAddUserDialog(context, ref, l10n),
            tooltip: l10n.addUser,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminUsersProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchUsers,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.invalidate(adminUsersProvider);
              },
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(
                child: AppLoaderCircular(),
              ),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(adminUsersProvider),
                ),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: l10n.noUsersFound,
                    message: l10n.noUsersFound,
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 50),
                      child: _UserTile(
                        user: user,
                        l10n: l10n,
                        onStatusChanged: (status) async {
                          final adminService =
                              ref.read(adminServiceProvider);
                          await adminService.updateUser(
                            user.copyWith(status: status),
                          );
                          ref.invalidate(adminUsersProvider);
                        },
                        onDelete: () async {
                          final adminService =
                              ref.read(adminServiceProvider);
                          await adminService.deleteUser(user.id);
                          ref.invalidate(adminUsersProvider);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    AdminRole selectedRole = AdminRole.admin;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addUser),
        content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.fullName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AdminRole>(
              value: selectedRole,
              decoration: InputDecoration(
                labelText: l10n.role,
                border: const OutlineInputBorder(),
              ),
              items: AdminRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(_roleLabel(role, AppLocalizations.of(context))),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) selectedRole = value;
              },
            ),
          ],
        ),
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final adminService = ref.read(adminServiceProvider);
              await adminService.createUser(
                AdminUser(
                  id: '',
                  name: nameController.text,
                  email: emailController.text,
                  role: selectedRole,
                  status: AdminUserStatus.pending,
                  createdAt: DateTime.now(),
                ),
              );
              ref.invalidate(adminUsersProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.l10n,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final AdminUser user;
  final AppLocalizations l10n;
  final Function(AdminUserStatus) onStatusChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(user.name[0])),
      title: Text(user.name),
      subtitle: Text(user.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoleChip(role: user.role),
          const SizedBox(width: 8),
          _StatusDot(status: user.status),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'activate':
                  onStatusChanged(AdminUserStatus.active);
                  break;
                case 'suspend':
                  onStatusChanged(AdminUserStatus.suspended);
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (user.status != AdminUserStatus.active)
                PopupMenuItem(
                  value: 'activate',
                  child: Text(l10n.activate),
                ),
              if (user.status != AdminUserStatus.suspended)
                PopupMenuItem(
                  value: 'suspend',
                  child: Text(l10n.suspend),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  l10n.delete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(user.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.email}: ${user.email}'),
                const SizedBox(height: 4),
                Text('${l10n.role}: ${_roleLabel(user.role, l10n)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      AdminRole.owner => AppColors.errorLight,
      AdminRole.countryAdmin => const Color(0xFF6200EE),
      AdminRole.governorateAdmin => AppColors.warningLight,
      AdminRole.centerAdmin => AppColors.infoLight,
      AdminRole.villageAdmin => AppColors.successLight,
      AdminRole.admin => AppColors.infoLight,
    };

    return Chip(
      label: Text(
        _roleLabel(role, AppLocalizations.of(context)),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final AdminUserStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AdminUserStatus.active => AppColors.successLight,
      AdminUserStatus.pending => AppColors.warningLight,
      AdminUserStatus.suspended => AppColors.errorLight,
      AdminUserStatus.deactivated => Theme.of(context).colorScheme.onSurfaceVariant,
    };

    return Tooltip(
      message: status.name,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
