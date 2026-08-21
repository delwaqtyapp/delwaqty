import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/constants/app_constants.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';

class AdminHierarchyPage extends ConsumerStatefulWidget {
  const AdminHierarchyPage({super.key});

  @override
  ConsumerState<AdminHierarchyPage> createState() => _AdminHierarchyPageState();
}

class _AdminHierarchyPageState extends ConsumerState<AdminHierarchyPage> {
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  AdminRole? _currentRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = Supabase.instance.client;
      final email = client.auth.currentUser?.email ?? '';
      final isOwner = email == AppConstants.ownerEmail;

      final profileResult = await client.rpc('get_admin_profile', params: {
        'p_email': email,
      });

      final profile = (profileResult as Map<String, dynamic>?) ?? {};
      _currentRole = isOwner
          ? AdminRole.owner
          : AdminRole.fromDb(profile['role'] as String?);

      final adminsResult = await client.rpc('get_all_admins');
      final admins = (adminsResult as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      if (mounted) {
        setState(() {
          _admins = admins;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.permissionDelegation),
        actions: [
          if (_currentRole != null && _currentRole!.hierarchyLevel < 4)
            IconButton(
              icon: const Icon(Icons.person_add_rounded),
              onPressed: () => _showAssignDialog(l10n),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_outlined, size: 64, color: cs.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(l10n.noAdmins),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _admins.length,
                  itemBuilder: (context, index) {
                    final admin = _admins[index];
                    return AnimatedFadeIn(
                      delay: Duration(milliseconds: index * 50),
                      child: _buildAdminCard(admin, l10n, cs),
                    );
                  },
                ),
    );
  }

  Widget _buildAdminCard(
    Map<String, dynamic> admin,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final email = admin['email'] as String? ?? '';
    final role = admin['role'] as String? ?? 'admin';
    final regionName = admin['region_name'] as String?;
    final isActive = admin['is_active'] as bool? ?? true;
    final isOwner = email == AppConstants.ownerEmail;
    final adminRole = AdminRole.fromDb(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isOwner
                      ? Colors.amber
                      : isActive
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                  child: Icon(
                    isOwner ? Icons.star_rounded : Icons.admin_panel_settings_rounded,
                    color: isOwner ? Colors.amber.shade800 : cs.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isOwner
                            ? l10n.ownerFullAccess
                            : _roleDisplayName(role, l10n),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Suspended',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
            if (regionName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    regionName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (!isOwner && _currentRole != null && _canManageAdmin(adminRole)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditRoleDialog(admin, l10n),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: Text(l10n.adminRole),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAssignRegionDialog(admin, l10n),
                      icon: const Icon(Icons.location_on_rounded, size: 16),
                      label: Text(l10n.assignRegion),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _canManageAdmin(AdminRole targetRole) {
    if (_currentRole == null) return false;
    return _currentRole!.canAssignRole(targetRole);
  }

  void _showAssignDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) {
        final emailController = TextEditingController();
        AdminRole selectedRole = AdminRole.villageAdmin;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(l10n.assignSubAdmin),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AdminRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: AdminRole.values
                          .where((r) => r != AdminRole.owner && r != AdminRole.admin)
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(_roleDisplayName(r.toDb(), l10n)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedRole = v);
                      },
                    ),
                  ],
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop({
                      'email': emailController.text.trim(),
                      'role': selectedRole.toDb(),
                    });
                  },
                  child: Text(l10n.assignSubAdmin),
                ),
              ],
            );
          },
        );
      },
    ).then((result) async {
      if (result == null) return;
      try {
        final client = Supabase.instance.client;
        await client.rpc('assign_admin_role', params: {
          'p_email': result['email'],
          'p_role': result['role'],
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.adminAssigned)),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred(e))),
          );
        }
      }
    });
  }

  void _showEditRoleDialog(Map<String, dynamic> admin, AppLocalizations l10n) {
    final email = admin['email'] as String;
    final currentRole = AdminRole.fromDb(admin['role'] as String?);

    showDialog(
      context: context,
      builder: (ctx) {
        AdminRole selectedRole = currentRole;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('${l10n.adminRole}: $email'),
              content: DropdownButtonFormField<AdminRole>(
                initialValue: selectedRole,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: AdminRole.values
                    .where((r) => r != AdminRole.owner)
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(_roleDisplayName(r.toDb(), l10n)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedRole = v);
                },
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(selectedRole.toDb());
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    ).then((newRole) async {
      if (newRole == null) return;
      try {
        final client = Supabase.instance.client;
        await client.rpc('assign_admin_role', params: {
          'p_email': email,
          'p_role': newRole,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.roleUpdated)),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred(e))),
          );
        }
      }
    });
  }

  void _showAssignRegionDialog(Map<String, dynamic> admin, AppLocalizations l10n) {
    final email = admin['email'] as String;

    showDialog(
      context: context,
      builder: (ctx) {
        final regionController = TextEditingController(
          text: admin['region_name'] as String? ?? '',
        );

        return AlertDialog(
          title: Text('${l10n.assignRegion}: $email'),
          content: TextField(
            controller: regionController,
            decoration: InputDecoration(
              labelText: l10n.adminAssignedRegion,
              border: const OutlineInputBorder(),
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop(regionController.text.trim());
              },
              child: Text(l10n.assignRegion),
            ),
          ],
        );
      },
    ).then((region) async {
      if (region == null) return;
      try {
        final client = Supabase.instance.client;
        await client.rpc('assign_admin_region', params: {
          'p_email': email,
          'p_region': region,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Region assigned')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorOccurred(e))),
          );
        }
      }
    });
  }

  String _roleDisplayName(String role, AppLocalizations l10n) => switch (role) {
    'country_admin' => l10n.countryAdmin,
    'governorate_admin' => l10n.governorateAdmin,
    'center_admin' => l10n.centerAdmin,
    'village_admin' => l10n.villageAdmin,
    _ => l10n.adminRole,
  };
}
