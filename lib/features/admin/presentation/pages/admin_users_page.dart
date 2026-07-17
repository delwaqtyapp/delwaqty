import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/services/admin/admin_service.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';

class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showAddUserDialog(context, ref),
            tooltip: 'Add Admin User',
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
                hintText: 'Search users...',
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Text('No users found'));
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _UserTile(
                      user: user,
                      onStatusChanged: (status) async {
                        final adminService = ref.read(adminServiceProvider);
                        await adminService.updateUser(
                          user.copyWith(status: status),
                        );
                        ref.invalidate(adminUsersProvider);
                      },
                      onDelete: () async {
                        final adminService = ref.read(adminServiceProvider);
                        await adminService.deleteUser(user.id);
                        ref.invalidate(adminUsersProvider);
                      },
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

  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    AdminRole selectedRole = AdminRole.support;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Admin User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AdminRole>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: AdminRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) selectedRole = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final AdminUser user;
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
                const PopupMenuItem(value: 'activate', child: Text('Activate')),
              if (user.status != AdminUserStatus.suspended)
                const PopupMenuItem(value: 'suspend', child: Text('Suspend')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      onTap: () {},
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      AdminRole.superAdmin => Colors.red,
      AdminRole.admin => Colors.blue,
      AdminRole.moderator => Colors.orange,
      AdminRole.support => Colors.green,
    };

    return Chip(
      label: Text(
        role.name.toUpperCase(),
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
      AdminUserStatus.active => Colors.green,
      AdminUserStatus.pending => Colors.orange,
      AdminUserStatus.suspended => Colors.red,
      AdminUserStatus.deactivated => Colors.grey,
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
