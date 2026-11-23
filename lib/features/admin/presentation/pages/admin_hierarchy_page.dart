import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/features/_shared/regions/presentation/widgets/region_picker_sheet.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/constants/app_constants.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';

import 'dart:async';

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
      final isOwner = ref.watch(adminIsOwnerProvider).value ?? false;

      final profileResult = await client.rpc(
        'get_admin_profile',
        params: {'p_email': email},
      );

      final profile = (profileResult as Map<String, dynamic>?) ?? {};
      _currentRole = isOwner
          ? AdminRole.owner
          : AdminRole.fromDb(profile['role'] as String?);

      final adminsResult = await client.rpc('get_all_admins');
      final admins =
          (adminsResult as List<dynamic>?)
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
              tooltip: l10n.assignSubAdmin,
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
                  Icon(
                    Icons.group_outlined,
                    size: 64,
                    color: cs.onSurfaceVariant,
                  ),
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
                    isOwner
                        ? Icons.star_rounded
                        : Icons.admin_panel_settings_rounded,
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
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        isOwner
                            ? l10n.ownerFullAccess
                            : _roleDisplayName(role, l10n),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                  Expanded(
                    child: Text(
                      regionName,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (!isOwner &&
                _currentRole != null &&
                _canManageAdmin(adminRole)) ...[
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
    final emailController = TextEditingController();
    final searchController = TextEditingController();
    AdminRole selectedRole = AdminRole.villageAdmin;
    String? selectedRegionId;
    String? selectedRegionName;
    String? selectedMemberId;
    String? selectedMemberName;
    List<Map<String, dynamic>> searchResults = const [];
    bool isSearching = false;
    bool initializedSearch = false;
    Timer? debounce;

    Future<void> runMemberSearch(
      String query,
      void Function(void Function()) setDialogState,
    ) async {
      setDialogState(() => isSearching = true);
      try {
        final client = Supabase.instance.client;
        final q = query.trim();
        var req = client
            .from('users')
            .select('id, full_name, email, phone, role');
        if (q.isNotEmpty) {
          req = req.or(
            'full_name.ilike.%$q%,email.ilike.%$q%,phone.ilike.%$q%',
          );
        }
        final rows = await req.limit(15);
        setDialogState(() {
          searchResults = (rows as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          isSearching = false;
        });
      } catch (_) {
        setDialogState(() => isSearching = false);
      }
    }

    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            if (!initializedSearch) {
              initializedSearch = true;
              Future.microtask(() => runMemberSearch('', setDialogState));
            }
            final lang = Localizations.localeOf(ctx).languageCode;

            return AlertDialog(
              title: Text(l10n.assignSubAdmin),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          labelText:
                              '${l10n.search} (${l10n.nameLabel} / ${l10n.phone})',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    searchController.clear();
                                    runMemberSearch('', setDialogState);
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          debounce?.cancel();
                          debounce = Timer(
                            const Duration(milliseconds: 280),
                            () => runMemberSearch(val, setDialogState),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      if (isSearching)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        )
                      else if (searchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 160),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(ctx).colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: searchResults.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final m = searchResults[index];
                              final id = m['id'] as String? ?? '';
                              final name =
                                  (m['full_name'] as String?)?.trim() ?? '';
                              final email =
                                  (m['email'] as String?)?.trim() ?? '';
                              final phone =
                                  (m['phone'] as String?)?.trim() ?? '';
                              final isSelected = selectedMemberId == id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                leading: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 20,
                                ),
                                title: Text(
                                  name.isNotEmpty
                                      ? name
                                      : (email.isNotEmpty ? email : phone),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  [
                                    if (email.isNotEmpty) email,
                                    if (phone.isNotEmpty) phone,
                                  ].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  setDialogState(() {
                                    selectedMemberId = id;
                                    selectedMemberName = name.isNotEmpty
                                        ? name
                                        : (email.isNotEmpty ? email : id);
                                    emailController.text = email.isNotEmpty
                                        ? email
                                        : id;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      if (selectedMemberName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${l10n.adminMembers}: $selectedMemberName',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: l10n.adminMgmtEmail,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AdminRole>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(
                          labelText: l10n.adminRole,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: AdminRole.values
                            .where(
                              (r) =>
                                  r != AdminRole.owner && r != AdminRole.admin,
                            )
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(_roleDisplayName(r.toDb(), l10n)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedRole = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await RegionPickerSheet.show(
                            ctx,
                            selectedRegionId: selectedRegionId,
                          );
                          if (picked != null && ctx.mounted) {
                            setDialogState(() {
                              selectedRegionId = picked.id;
                              selectedRegionName = picked.displayName(lang);
                            });
                          }
                        },
                        icon: const Icon(Icons.location_on_rounded, size: 18),
                        label: Text(
                          selectedRegionName ?? l10n.assignRegion,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
                      'member_id': selectedMemberId,
                      'role': selectedRole.toDb(),
                      'region_id': selectedRegionId,
                      'region_name': selectedRegionName,
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
      debounce?.cancel();
      if (result == null) return;
      final identifier = (result['email'] as String?)?.trim() ?? '';
      if (identifier.isEmpty) return;

      try {
        final client = Supabase.instance.client;
        await client.rpc(
          'assign_admin_role',
          params: {'p_email': identifier, 'p_role': result['role']},
        );

        final regionId = result['region_id'] as String?;
        final regionName = result['region_name'] as String?;
        if (regionId != null && regionId.isNotEmpty) {
          try {
            await client.rpc(
              'admin_assign_region_by_id',
              params: {'p_email': identifier, 'p_region_id': regionId},
            );
          } on PostgrestException {
            if (regionName != null && regionName.isNotEmpty) {
              await client.rpc(
                'assign_admin_region',
                params: {'p_email': identifier, 'p_region': regionName},
              );
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.adminAssigned)));
          unawaited(_loadData());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
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
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: AdminRole.values
                    .where((r) => r != AdminRole.owner)
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(_roleDisplayName(r.toDb(), l10n)),
                      ),
                    )
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
        await client.rpc(
          'assign_admin_role',
          params: {'p_email': email, 'p_role': newRole},
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.roleUpdated)));
          unawaited(_loadData());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
        }
      }
    });
  }

  Future<void> _showAssignRegionDialog(
    Map<String, dynamic> admin,
    AppLocalizations l10n,
  ) async {
    final email = admin['email'] as String;
    final region = await RegionPickerSheet.show(
      context,
      selectedRegionId: admin['region_id'] as String?,
    );
    if (region == null || !mounted) return;

    try {
      final client = Supabase.instance.client;
      try {
        await client.rpc(
          'admin_assign_region_by_id',
          params: {'p_email': email, 'p_region_id': region.id},
        );
      } on PostgrestException catch (e) {
        if (e.code != 'PGRST202') rethrow;
        await client.rpc(
          'assign_admin_region',
          params: {'p_email': email, 'p_region': region.nameAr},
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.regionSaved)));
        unawaited(_loadData());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
    }
  }

  String _roleDisplayName(String role, AppLocalizations l10n) => switch (role) {
    'country_admin' => l10n.countryAdmin,
    'governorate_admin' => l10n.governorateAdmin,
    'center_admin' => l10n.centerAdmin,
    'village_admin' => l10n.villageAdmin,
    _ => l10n.adminRole,
  };
}
