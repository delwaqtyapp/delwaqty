import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_region_assignment.dart';
import 'package:delwaqty/features/admin/presentation/providers/admin_region_providers.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/features/_shared/regions/presentation/widgets/region_browser.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';

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
            content: Text(appErrorText(context, e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeAssignment(String adminId, String regionId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.delete,
      message: l10n.areYouSure,
      confirmLabel: l10n.delete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
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
            content: Text(appErrorText(context, e)),
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
    final assignmentsAsync = _selectedAdminId == null
        ? null
        : ref.watch(adminRegionAssignmentsProvider(_selectedAdminId));

    final l10n = AppLocalizations.of(context);
    final padding = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 32.0;
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminRegionScopeTitle,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1035),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.adminRegionScopeSubtitle,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Expanded(
            // Under ~600px the panels stack vertically instead of
            // squeezing the fixed 300px users panel beside the gap.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final usersPanel = _UsersPanel(
                  usersAsync: usersAsync,
                  selectedAdminId: _selectedAdminId,
                  onSelect: _selectAdmin,
                  onRetry: () => ref.invalidate(adminTierUsersProvider),
                );
                final assignmentsPanel = _AssignmentsPanel(
                  selectedAdminId: _selectedAdminId,
                  assignmentsAsync: assignmentsAsync,
                  pendingRegionId: _pendingRegionId,
                  pendingScope: _pendingScope,
                  saving: _saving,
                  onPendingRegionChanged: (value) =>
                      setState(() => _pendingRegionId = value),
                  onPendingScopeChanged: (value) =>
                      setState(() => _pendingScope = value),
                  onAdd: _addAssignment,
                  onRemove: _removeAssignment,
                );
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      Expanded(child: usersPanel),
                      const SizedBox(height: 16),
                      Expanded(child: assignmentsPanel),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 300, child: usersPanel),
                    const SizedBox(width: 24),
                    Expanded(child: assignmentsPanel),
                  ],
                );
              },
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
    required this.onRetry,
  });

  final AsyncValue<List<Map<String, dynamic>>> usersAsync;
  final String? selectedAdminId;
  final void Function(String adminId) onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: appErrorText(context, e),
          retryLabel: AppLocalizations.of(context).errorRetryCta,
          onRetry: onRetry,
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(child: Text(l10n.adminMgmtNoAdmins));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final id = user['id'] as String;
              final name =
                  user['full_name'] as String? ?? l10n.adminMgmtUnknown;
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

/// Resolves a possibly deep region assignment to its display name.
class _AssignedRegionName extends ConsumerWidget {
  const _AssignedRegionName({required this.regionId});

  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(regionByIdProvider(regionId)).value;
    return Text(region?.displayName('en') ?? regionId);
  }
}

/// Picker field that opens the cascading [RegionBrowser] bottom sheet.
class _RegionPickerField extends ConsumerWidget {
  const _RegionPickerField({
    required this.onPendingRegionChanged,
    required this.pendingRegionId,
    this.enabled = true,
  });

  final String? pendingRegionId;
  final void Function(String?) onPendingRegionChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = pendingRegionId;
    final selectedRegion = pending == null
        ? null
        : ref.watch(regionByIdProvider(pending)).value;

    return InkWell(
      key: const Key('region-picker'),
      onTap: enabled
          ? () {
              showModalBottomSheet<Region>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (sheetContext) {
                  return SizedBox(
                    height: MediaQuery.of(sheetContext).size.height * 0.7,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l10n.selectRegion,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: RegionBrowser(
                            selectedRegionId: pendingRegionId,
                            onSelected: (region) {
                              Navigator.of(sheetContext).pop(region);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ).then((region) {
                if (region is Region) {
                  onPendingRegionChanged(region.id);
                }
              });
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Region',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: selectedRegion == null
            ? Text(
                pendingRegionId == null ? 'Select region (any level)' : '…',
                style: const TextStyle(color: Colors.black54),
              )
            : Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedRegion.displayName('en'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1035),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AssignmentsPanel extends ConsumerWidget {
  const _AssignmentsPanel({
    required this.selectedAdminId,
    required this.assignmentsAsync,
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
  final String? pendingRegionId;
  final AdminRegionScope pendingScope;
  final bool saving;
  final void Function(String?) onPendingRegionChanged;
  final void Function(AdminRegionScope) onPendingScopeChanged;
  final Future<void> Function(String adminId) onAdd;
  final Future<void> Function(String adminId, String regionId) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (selectedAdminId == null) {
      return _EmptyPanel(message: l10n.adminRegionSelectUser);
    }
    final assignments =
        assignmentsAsync?.value ?? const <AdminRegionAssignment>[];
    final assignedIds = assignments.map((a) => a.regionId).toSet();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
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
            child:
                assignmentsAsync != null &&
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
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final assignment = assignments[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.location_city_rounded,
                          color: AppColors.brandPurple,
                        ),
                        title: _AssignedRegionName(
                          regionId: assignment.regionId,
                        ),
                        subtitle: Text(
                          assignment.scope == AdminRegionScope.self
                              ? 'This region only'
                              : 'This region + descendants',
                        ),
                        trailing: IconButton(
                          tooltip: l10n.delete,
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
                child: _RegionPickerField(
                  pendingRegionId: pendingRegionId,
                  enabled: !saving,
                  onPendingRegionChanged: onPendingRegionChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<AdminRegionScope>(
                  key: const Key('scope-select'),
                  initialValue: pendingScope,
                  decoration: const InputDecoration(
                    labelText: 'Scope',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: AdminRegionScope.descendants,
                      child: Text(l10n.descendants),
                    ),
                    DropdownMenuItem(
                      value: AdminRegionScope.self,
                      child: Text(l10n.self),
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
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed:
                  (saving ||
                      pendingRegionId == null ||
                      assignedIds.contains(pendingRegionId))
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
              label: Text(l10n.add),
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
