import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_region_assignment.dart';
import 'package:delwaqty/features/admin/presentation/providers/admin_region_providers.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';

class AdminRegionScopePage extends ConsumerStatefulWidget {
  const AdminRegionScopePage({super.key});

  @override
  ConsumerState<AdminRegionScopePage> createState() =>
      _AdminRegionScopePageState();
}

class _AdminRegionScopePageState extends ConsumerState<AdminRegionScopePage> {
  String? _selectedAdminId;
  String? _pendingRegionId;
  AdminRegionScope _pendingScope = AdminRegionScope.descendants;
  bool _saving = false;

  void _selectAdmin(String adminId) {
    setState(() {
      _selectedAdminId = adminId;
      _pendingRegionId = null;
    });
  }

  Future<void> _addAssignment(String adminId) async {
    final regionId = _pendingRegionId;
    if (regionId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(upsertAdminRegionAssignmentProvider)(
        adminId: adminId,
        regionId: regionId,
        scope: _pendingScope,
      );
      setState(() => _pendingRegionId = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving assignment: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeAssignment(String adminId, String regionId) async {
    setState(() => _saving = true);
    try {
      await ref.read(deleteAdminRegionAssignmentProvider)(
        adminId: adminId,
        regionId: regionId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing assignment: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminTierUsersProvider);
    final governoratesAsync = ref.watch(governoratesProvider);
    final assignmentsAsync = _selectedAdminId == null
        ? null
        : ref.watch(adminRegionAssignmentsProvider(_selectedAdminId));

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Region Scope',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1035),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Assign governorate scope to admin-tier users. An admin with no '
            'assignments is global.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 300,
                  child: _UsersPanel(
                    usersAsync: usersAsync,
                    selectedAdminId: _selectedAdminId,
                    onSelect: _selectAdmin,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _AssignmentsPanel(
                    selectedAdminId: _selectedAdminId,
                    assignmentsAsync: assignmentsAsync,
                    governoratesAsync: governoratesAsync,
                    pendingRegionId: _pendingRegionId,
                    pendingScope: _pendingScope,
                    saving: _saving,
                    onPendingRegionChanged: (value) => setState(
                      () => _pendingRegionId = value,
                    ),
                    onPendingScopeChanged: (value) => setState(
                      () => _pendingScope = value,
                    ),
                    onAdd: _addAssignment,
                    onRemove: _removeAssignment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersPanel extends StatelessWidget {
  const _UsersPanel({
    required this.usersAsync,
    required this.selectedAdminId,
    required this.onSelect,
  });

  final AsyncValue<List<Map<String, dynamic>>> usersAsync;
  final String? selectedAdminId;
  final void Function(String adminId) onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No admin-tier users'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final id = user['id'] as String;
              final name = user['full_name'] as String? ?? 'Unknown';
              final email = user['email'] as String? ?? '';
              final selected = id == selectedAdminId;
              return InkWell(
                onTap: () => onSelect(id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brandLavender
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.brandPurpleDeep
                              : const Color(0xFF1A1035),
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AssignmentsPanel extends StatelessWidget {
  const _AssignmentsPanel({
    required this.selectedAdminId,
    required this.assignmentsAsync,
    required this.governoratesAsync,
    required this.pendingRegionId,
    required this.pendingScope,
    required this.saving,
    required this.onPendingRegionChanged,
    required this.onPendingScopeChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final String? selectedAdminId;
  final AsyncValue<List<AdminRegionAssignment>>? assignmentsAsync;
  final AsyncValue<List<Region>> governoratesAsync;
  final String? pendingRegionId;
  final AdminRegionScope pendingScope;
  final bool saving;
  final void Function(String?) onPendingRegionChanged;
  final void Function(AdminRegionScope) onPendingScopeChanged;
  final Future<void> Function(String adminId) onAdd;
  final Future<void> Function(String adminId, String regionId) onRemove;

  Region? _findRegion(List<Region> governorates, String regionId) {
    for (final region in governorates) {
      if (region.id == regionId) return region;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (selectedAdminId == null) {
      return const _EmptyPanel(message: 'Select an admin user to manage scope');
    }
    final governorates = governoratesAsync.value ?? const <Region>[];
    final assignments = assignmentsAsync?.value ?? const <AdminRegionAssignment>[];
    final assignedIds = assignments.map((a) => a.regionId).toSet();
    final available = governorates
        .where((r) => !assignedIds.contains(r.id))
        .toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned regions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1035),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: assignmentsAsync != null &&
                    assignmentsAsync!.isLoading &&
                    assignments.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : assignments.isEmpty
                    ? const Center(
                        child: Text(
                          'No assignments — admin is global',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: assignments.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final assignment = assignments[index];
                          final region = _findRegion(
                            governorates,
                            assignment.regionId,
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.location_city_rounded,
                              color: AppColors.brandPurple,
                            ),
                            title: Text(
                              region?.displayName('en') ??
                                  assignment.regionId,
                            ),
                            subtitle: Text(
                              assignment.scope == AdminRegionScope.self
                                  ? 'This region only'
                                  : 'This region + descendants',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: saving
                                  ? null
                                  : () => onRemove(
                                      assignment.adminId,
                                      assignment.regionId,
                                    ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String?>(
                  key: const Key('region-select'),
                  value: pendingRegionId,
                  decoration: const InputDecoration(
                    labelText: 'Governorate',
                    border: OutlineInputBorder(),
                  ),
                  items: available
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(r.displayName('en')),
                        ),
                      )
                      .toList(),
                  onChanged: saving ? null : onPendingRegionChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<AdminRegionScope>(
                  key: const Key('scope-select'),
                  value: pendingScope,
                  decoration: const InputDecoration(
                    labelText: 'Scope',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AdminRegionScope.descendants,
                      child: Text('Descendants'),
                    ),
                    DropdownMenuItem(
                      value: AdminRegionScope.self,
                      child: Text('Self'),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) onPendingScopeChanged(value);
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: (saving || pendingRegionId == null)
                  ? null
                  : () => onAdd(selectedAdminId!),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
              ),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey[600])),
    );
  }
}
