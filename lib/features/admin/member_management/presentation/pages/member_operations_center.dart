import 'dart:async';

import 'package:delwaqty/core/utils/avatar_initial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/_shared/regions/presentation/widgets/region_picker_sheet.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/features/admin/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/admin/member_management/presentation/member_providers.dart';
import 'package:delwaqty/features/admin/member_management/presentation/pages/member_drawer.dart';
import 'package:delwaqty/features/admin_management/presentation/providers/admin_management_providers.dart';
import 'package:delwaqty/shared/widgets/animated_feedback.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

const Set<String> _kAdminRoles = {
  'admin',
  'owner',
  'super_admin',
  'country_admin',
  'governorate_admin',
  'center_admin',
  'village_admin',
};

bool _isAdminRoleOrType(String? role, [String? userType]) {
  return _kAdminRoles.contains(role) || userType == 'admin';
}

class MemberOperationsCenter extends ConsumerStatefulWidget {
  const MemberOperationsCenter({super.key});

  @override
  ConsumerState<MemberOperationsCenter> createState() =>
      _MemberOperationsCenterState();
}

class _MemberOperationsCenterState
    extends ConsumerState<MemberOperationsCenter> {
  final ValueNotifier<String?> _selectedMemberId = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _selectedMemberId.dispose();
    super.dispose();
  }

  void _selectMember(String? memberId) {
    _selectedMemberId.value = memberId;
  }

  void _showAssignAdminFromMembersSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AssignAdminFromMembersSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 728;

    return Scaffold(
      appBar: AppBar(
        leading: MediaQuery.sizeOf(context).width < 1100
            ? const AdminMenuButton()
            : null,
        title: Text(AppLocalizations.of(context).memberOperationsCenter),
        actions: [
          IconButton(
            tooltip: l10n.assignSubAdmin,
            icon: const Icon(Icons.admin_panel_settings_rounded),
            onPressed: () => _showAssignAdminFromMembersSheet(context),
          ),
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(memberOpsProvider);
              ref.invalidate(memberOpsCountProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _MemberQuickAction(
                  icon: Icons.admin_panel_settings_rounded,
                  label: l10n.assignSubAdmin,
                  color: const Color(0xFF5B3DF0),
                  onTap: () => _showAssignAdminFromMembersSheet(context),
                ),
                _MemberQuickAction(
                  icon: Icons.verified_user_rounded,
                  label: l10n.adminVerifications,
                  color: const Color(0xFF34C759),
                  onTap: () => context.push('/admin/verifications'),
                ),
                _MemberQuickAction(
                  icon: Icons.fact_check_rounded,
                  label: l10n.adminApprovals,
                  color: const Color(0xFF007AFF),
                  onTap: () => context.push('/admin/approvals'),
                ),
                _MemberQuickAction(
                  icon: Icons.person_remove_rounded,
                  label: l10n.pendingDeletions,
                  color: const Color(0xFFDC2626),
                  onTap: () => context.push('/admin/pending-deletions'),
                ),
                _MemberQuickAction(
                  icon: Icons.gavel_rounded,
                  label: l10n.sanctions,
                  color: const Color(0xFFFF9500),
                  onTap: () => context.push('/admin/sanctions'),
                ),
                _MemberQuickAction(
                  icon: Icons.warning_amber_rounded,
                  label: l10n.complaints,
                  color: const Color(0xFFFF3B30),
                  onTap: () => context.push('/admin/complaints'),
                ),
                _MemberQuickAction(
                  icon: Icons.map_rounded,
                  label: l10n.liveTracking,
                  color: const Color(0xFF00C7BE),
                  onTap: () => context.push('/admin/live-tracking'),
                ),
                _MemberQuickAction(
                  icon: Icons.priority_high_rounded,
                  label: l10n.adminEscalations,
                  color: const Color(0xFFFF6482),
                  onTap: () => context.push('/admin/escalations'),
                ),
              ],
            ),
          ),
          Expanded(
            child: isDesktop
                ? _DesktopLayout(
                    selectedMemberId: _selectedMemberId,
                    onSelectMember: _selectMember,
                  )
                : _MobileLayout(
                    selectedMemberId: _selectedMemberId,
                    onSelectMember: _selectMember,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLayout extends ConsumerWidget {
  const _DesktopLayout({
    required this.selectedMemberId,
    required this.onSelectMember,
  });

  final ValueNotifier<String?> selectedMemberId;
  final void Function(String?) onSelectMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _MemberListPanel(
            selectedMemberId: selectedMemberId.value,
            onSelectMember: onSelectMember,
          ),
        ),
        Container(width: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
        ValueListenableBuilder<String?>(
          valueListenable: selectedMemberId,
          builder: (context, memberId, _) {
            if (memberId == null) {
              return Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        size: 64,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.selectMemberHint,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Expanded(
              flex: 3,
              child: MemberDrawer(
                memberId: memberId,
                onDismiss: () => onSelectMember(null),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({
    required this.selectedMemberId,
    required this.onSelectMember,
  });

  final ValueNotifier<String?> selectedMemberId;
  final void Function(String?) onSelectMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedMemberId,
      builder: (context, memberId, _) {
        if (memberId != null) {
          return MemberDrawer(
            memberId: memberId,
            onDismiss: () => onSelectMember(null),
          );
        }
        return _MemberListPanel(
          selectedMemberId: null,
          onSelectMember: (id) {
            if (id != null) {
              onSelectMember(id);
            }
          },
        );
      },
    );
  }
}

class _MemberListPanel extends ConsumerStatefulWidget {
  const _MemberListPanel({
    required this.selectedMemberId,
    required this.onSelectMember,
  });

  final String? selectedMemberId;
  final void Function(String?) onSelectMember;

  @override
  ConsumerState<_MemberListPanel> createState() => _MemberListPanelState();
}

class _MemberListPanelState extends ConsumerState<_MemberListPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _roleFilter;
  String? _accountStatusFilter;
  String? _verificationStatusFilter;
  String? _sortBy;
  String? _serviceCategoryFilter;
  String? _sanctionStatusFilter;
  final int _limit = 25;
  final int _offset = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final isAdminFilter = _roleFilter == 'admin';
    final filters = {
      'search': _search,
      'role': isAdminFilter ? null : _roleFilter,
      'userType': null,
      'accountStatus': _accountStatusFilter,
      'verificationStatus': _verificationStatusFilter,
      'serviceCategory': _serviceCategoryFilter,
      'sanctionStatus': _sanctionStatusFilter,
      'sort': _sortBy ?? 'newest',
      'limit': isAdminFilter ? 100 : _limit,
      'offset': _offset,
    };
    ref.read(memberOpsProvider.notifier).setFilters(filters);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.search,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      tooltip: l10n.clear,
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              isDense: true,
            ),
            onChanged: (v) {
              setState(() => _search = v);
              _applyFilters();
            },
            onSubmitted: (_) => _applyFilters(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipWidget(
                  label: l10n.allRoles,
                  selected: _roleFilter == null,
                  onTap: () {
                    setState(() => _roleFilter = null);
                    _applyFilters();
                  },
                ),
                _FilterChipWidget(
                  label: l10n.customer,
                  selected: _roleFilter == 'customer',
                  onTap: () {
                    setState(() => _roleFilter = 'customer');
                    _applyFilters();
                  },
                ),
                _FilterChipWidget(
                  label: l10n.driver,
                  selected: _roleFilter == 'driver',
                  onTap: () {
                    setState(() => _roleFilter = 'driver');
                    _applyFilters();
                  },
                ),
                _FilterChipWidget(
                  label: l10n.merchant,
                  selected: _roleFilter == 'merchant',
                  onTap: () {
                    setState(() => _roleFilter = 'merchant');
                    _applyFilters();
                  },
                ),
                _FilterChipWidget(
                  label: l10n.adminRole,
                  selected: _roleFilter == 'admin',
                  onTap: () {
                    setState(
                      () =>
                          _roleFilter = _roleFilter == 'admin' ? null : 'admin',
                    );
                    _applyFilters();
                  },
                ),
                _FilterChipWidget(
                  label: l10n.active,
                  selected: _accountStatusFilter == 'active',
                  onTap: () {
                    setState(() {
                      _accountStatusFilter = _accountStatusFilter == 'active'
                          ? null
                          : 'active';
                    });
                    _applyFilters();
                  },
                ),
                _FilterChipWidget(
                  label: l10n.suspended,
                  selected: _accountStatusFilter == 'suspended',
                  onTap: () {
                    setState(() {
                      _accountStatusFilter = _accountStatusFilter == 'suspended'
                          ? null
                          : 'suspended';
                    });
                    _applyFilters();
                  },
                ),
                _FilterChipWidget(
                  label: l10n.unverified,
                  selected: _verificationStatusFilter == 'unverified',
                  onTap: () {
                    setState(() {
                      _verificationStatusFilter =
                          _verificationStatusFilter == 'unverified'
                          ? null
                          : 'unverified';
                    });
                    _applyFilters();
                  },
                ),
                _FilterChipWidget(
                  label: l10n.verified,
                  selected: _verificationStatusFilter == 'verified',
                  onTap: () {
                    setState(() {
                      _verificationStatusFilter =
                          _verificationStatusFilter == 'verified'
                          ? null
                          : 'verified';
                    });
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: DropdownButtonFormField<String>(
            initialValue: _sortBy,
            decoration: InputDecoration(
              labelText: l10n.sortBy,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: [
              DropdownMenuItem(value: 'newest', child: Text(l10n.newest)),
              DropdownMenuItem(value: 'oldest', child: Text(l10n.oldest)),
              DropdownMenuItem(value: 'name', child: Text(l10n.nameLabel)),
              DropdownMenuItem(value: 'orders', child: Text(l10n.orders)),
              DropdownMenuItem(value: 'wallet', child: Text(l10n.wallet)),
            ],
            onChanged: (value) {
              setState(() => _sortBy = value);
              _applyFilters();
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Builder(
            builder: (context) {
              final members = ref
                  .watch(memberOpsProvider)
                  .where(
                    (m) =>
                        m.accountStatus != 'deactivated' &&
                        !(m.fullName == null &&
                            (m.email?.endsWith('@anonymized.invalid') ??
                                false)) &&
                        (_roleFilter != 'admin' ||
                            _isAdminRoleOrType(m.role, m.userType)),
                  )
                  .toList();
              final notifier = ref.read(memberOpsProvider.notifier);
              if (members.isEmpty) {
                if (notifier.lastError != null) {
                  return PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: l10n.failedToLoadMembers,
                    message: appErrorText(context, notifier.lastError),
                    actionLabel: l10n.retryLabel,
                    onAction: () => notifier.refresh(),
                  );
                }
                return PremiumEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: l10n.noMembersFound,
                  message: l10n.tryAdjustingSearch,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isSelected = widget.selectedMemberId == member.id;
                  return _MemberTileWidget(
                    member: member,
                    isSelected: isSelected,
                    onTap: () => widget.onSelectMember(member.id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  const _FilterChipWidget({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsetsDirectional.only(end: 6),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.15)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? cs.primary : cs.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MemberTileWidget extends StatelessWidget {
  const _MemberTileWidget({
    required this.member,
    required this.isSelected,
    required this.onTap,
  });

  final Member member;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusColor = switch (member.accountStatus) {
      'active' => const Color(0xFF34C759),
      'restricted' => const Color(0xFFFF9500),
      'suspended' => const Color(0xFFFF3B30),
      'banned' => const Color(0xFF8B0000),
      _ => Colors.grey,
    };
    final roleColor = switch (member.role) {
      'admin' ||
      'owner' ||
      'super_admin' ||
      'country_admin' ||
      'governorate_admin' ||
      'center_admin' ||
      'village_admin' => const Color(0xFF5B3DF0),
      'driver' => const Color(0xFF007AFF),
      'merchant' => const Color(0xFFFF9500),
      'customer' => const Color(0xFF00C7BE),
      _ =>
        _isAdminRoleOrType(member.role, member.userType)
            ? const Color(0xFF5B3DF0)
            : Colors.blueGrey,
    };
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? cs.primaryContainer.withValues(alpha: 0.25)
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? cs.primary
              : cs.outlineVariant.withValues(alpha: 0.22),
          width: isSelected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: roleColor.withValues(alpha: 0.15),
                      child: Text(
                        safeInitialFrom([
                          member.fullName,
                          member.email,
                          member.username,
                        ]),
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.fullName ?? l10n.unnamed,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _roleLabel(l10n, member.role ?? ''),
                              style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        member.email?.isNotEmpty == true
                            ? '${member.email!} • ${_roleLabel(l10n, member.role ?? '')}'
                            : (member.phone ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _accountStatusLabel(
                          l10n,
                          member.accountStatus ?? 'active',
                        ),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _accountStatusLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      'active' => l10n.active,
      'suspended' => l10n.suspended,
      'restricted' => l10n.restrictAccount,
      'banned' => l10n.permanentBan,
      _ => key,
    };
  }

  String _roleLabel(AppLocalizations l10n, String role) {
    return switch (role) {
      'customer' => l10n.customer,
      'driver' => l10n.driver,
      'merchant' => l10n.merchant,
      'admin' => l10n.roleAdmin,
      'owner' => l10n.ownerFullAccess,
      'super_admin' => l10n.adminRole,
      'country_admin' => l10n.countryAdmin,
      'governorate_admin' => l10n.governorateAdmin,
      'center_admin' => l10n.centerAdmin,
      'village_admin' => l10n.villageAdmin,
      _ => role,
    };
  }
}

class _MemberQuickAction extends StatelessWidget {
  const _MemberQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<String> _kGranularPlatformPermissionCodes = [
  'USERS_VIEW',
  'USERS_MODERATE',
  'ORDERS_VIEW',
  'ORDERS_MANAGE',
  'FINANCE_VIEW',
  'FINANCE_APPROVE',
  'PROVIDERS_VERIFY',
  'DISPUTES_RESOLVE',
  'CAMPAIGNS_MANAGE',
  'ANALYTICS_VIEW',
  'ADMINS_MANAGE',
];

const List<({String role, IconData icon})> _kSelectableAdminRoles = [
  (role: 'country_admin', icon: Icons.public_rounded),
  (role: 'governorate_admin', icon: Icons.account_balance_rounded),
  (role: 'center_admin', icon: Icons.location_city_rounded),
  (role: 'village_admin', icon: Icons.holiday_village_rounded),
  (role: 'admin', icon: Icons.admin_panel_settings_rounded),
  (role: 'customer', icon: Icons.person_outline_rounded),
];

class _AssignAdminFromMembersSheet extends ConsumerStatefulWidget {
  const _AssignAdminFromMembersSheet();

  @override
  ConsumerState<_AssignAdminFromMembersSheet> createState() =>
      _AssignAdminFromMembersSheetState();
}

class _AssignAdminFromMembersSheetState
    extends ConsumerState<_AssignAdminFromMembersSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  bool _isLoadingPermissions = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _searchResults = const [];
  Map<String, dynamic>? _selectedMember;
  String _selectedRole = 'village_admin';
  String? _selectedRegionId;
  String? _selectedRegionName;
  final Set<String> _selectedPermissions = {};
  final Set<String> _initialGrantedPermissions = {};

  @override
  void initState() {
    super.initState();
    _searchMembers('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _permissionLabel(String code, AppLocalizations l10n) {
    return switch (code) {
      'USERS_VIEW' => l10n.adminMembers,
      'USERS_MODERATE' => l10n.sanctions,
      'ORDERS_VIEW' => l10n.orders,
      'ORDERS_MANAGE' => l10n.adminOrdersPage,
      'FINANCE_VIEW' => l10n.adminFinancialCenter,
      'FINANCE_APPROVE' => l10n.settlements,
      'PROVIDERS_VERIFY' => l10n.adminVerifications,
      'DISPUTES_RESOLVE' => l10n.complaints,
      'CAMPAIGNS_MANAGE' => l10n.adminBannersTitle,
      'ANALYTICS_VIEW' => l10n.adminAnalytics,
      'ADMINS_MANAGE' => l10n.adminMgmtList,
      _ => code,
    };
  }

  Future<void> _searchMembers(String query) async {
    setState(() => _isSearching = true);
    try {
      final client = Supabase.instance.client;
      final q = query.trim();
      List<dynamic> rows;
      try {
        var req = client
            .from('users')
            .select('id, full_name, email, phone, role, user_type, region_id');
        if (q.isNotEmpty) {
          req = req.or(
            'full_name.ilike.%$q%,email.ilike.%$q%,phone.ilike.%$q%',
          );
        }
        rows = await req.limit(20);
      } on PostgrestException {
        var req = client
            .from('users')
            .select('id, full_name, email, phone, role, user_type');
        if (q.isNotEmpty) {
          req = req.or(
            'full_name.ilike.%$q%,email.ilike.%$q%,phone.ilike.%$q%',
          );
        }
        rows = await req.limit(20);
      }
      if (!mounted) return;
      setState(() {
        _searchResults = rows
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _pickMember(Map<String, dynamic> member) async {
    final memberId = member['id'] as String? ?? '';
    final currentRole = member['role'] as String? ?? 'customer';
    final regionId = member['region_id'] as String?;

    setState(() {
      _selectedMember = member;
      _selectedRole = _kSelectableAdminRoles.any((r) => r.role == currentRole)
          ? currentRole
          : 'village_admin';
      _selectedRegionId = regionId;
      _selectedRegionName = null;
      _selectedPermissions.clear();
      _initialGrantedPermissions.clear();
      _isLoadingPermissions = true;
    });

    if (memberId.isEmpty) {
      setState(() => _isLoadingPermissions = false);
      return;
    }

    try {
      final client = Supabase.instance.client;
      final res = await client.rpc(
        'get_admin_permissions',
        params: {'p_admin_id': memberId},
      );
      if (res is Map) {
        final grants =
            (res['grants'] as List?)?.map((e) => e.toString()).toSet() ??
            <String>{};
        final effective =
            (res['effective'] as List?)?.map((e) => e.toString()).toSet() ??
            <String>{};
        if (mounted) {
          setState(() {
            _initialGrantedPermissions
              ..clear()
              ..addAll(grants);
            _selectedPermissions
              ..clear()
              ..addAll(
                _kGranularPlatformPermissionCodes.where(
                  (c) => grants.contains(c) || effective.contains(c),
                ),
              );
          });
        }
      }
    } catch (_) {
      // Member may not be an admin yet; start with empty permissions.
    } finally {
      if (mounted) {
        setState(() => _isLoadingPermissions = false);
      }
    }
  }

  Future<void> _saveConfiguration() async {
    final l10n = AppLocalizations.of(context);
    final member = _selectedMember;
    if (member == null) return;
    final memberId = member['id'] as String? ?? '';
    final email = (member['email'] as String?)?.trim() ?? '';
    final identifier = email.isNotEmpty ? email : memberId;
    if (memberId.isEmpty) return;

    setState(() => _isSaving = true);
    final client = Supabase.instance.client;

    try {
      bool configuredViaUnifiedRpc = false;
      try {
        await client.rpc(
          'admin_promote_and_configure_member',
          params: {
            'p_member_id': memberId,
            'p_role': _selectedRole,
            'p_region_id': _selectedRegionId,
            'p_permissions': _selectedPermissions.toList(),
          },
        );
        configuredViaUnifiedRpc = true;
      } on PostgrestException catch (e) {
        if (e.code != 'PGRST202') rethrow;
      }

      if (!configuredViaUnifiedRpc) {
        await client.rpc(
          'assign_admin_role',
          params: {'p_email': identifier, 'p_role': _selectedRole},
        );

        if (_selectedRole != 'customer' && _selectedRegionId != null) {
          try {
            await client.rpc(
              'admin_assign_region_by_id',
              params: {
                'p_email': identifier,
                'p_region_id': _selectedRegionId,
                'p_scope': 'descendants',
              },
            );
          } on PostgrestException {
            await client.rpc(
              'assign_admin_region',
              params: {
                'p_admin_id': memberId,
                'p_region_id': _selectedRegionId,
                'p_scope': 'descendants',
              },
            );
          }
        }

        if (_selectedRole != 'customer') {
          for (final code in _kGranularPlatformPermissionCodes) {
            final isSelected = _selectedPermissions.contains(code);
            final wasGranted = _initialGrantedPermissions.contains(code);
            if (isSelected && !wasGranted) {
              try {
                await client.rpc(
                  'grant_admin_permission',
                  params: {'p_admin_id': memberId, 'p_permission': code},
                );
              } catch (_) {}
            } else if (!isSelected && wasGranted) {
              try {
                await client.rpc(
                  'revoke_admin_permission',
                  params: {'p_admin_id': memberId, 'p_permission': code},
                );
              } catch (_) {}
            }
          }
        }
      }

      if (!mounted) return;
      ref.invalidate(memberOpsProvider);
      ref.invalidate(memberOpsCountProvider);
      ref.invalidate(memberOpsProfileProvider(memberId));
      ref.invalidate(adminsListProvider);
      ref.invalidate(adminDetailProvider(memberId));
      ref.invalidate(adminPermissionsProvider(memberId));

      showAnimatedSuccessToast(context, message: l10n.adminAssigned);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _roleBadgeText(String? role, AppLocalizations l10n) {
    return switch (role) {
      'owner' => l10n.ownerFullAccess,
      'super_admin' => l10n.adminRole,
      'country_admin' => l10n.countryAdmin,
      'governorate_admin' => l10n.governorateAdmin,
      'center_admin' => l10n.centerAdmin,
      'village_admin' => l10n.villageAdmin,
      'admin' => l10n.adminRole,
      'driver' => l10n.driver,
      'merchant' => l10n.merchant,
      'provider' => l10n.chatOriginProvider,
      _ => l10n.customer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.86;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF5B3DF0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.assignSubAdmin,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedMember == null
                ? _buildSearchAndPickStep(cs, l10n)
                : _buildConfigureMemberStep(cs, lang, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndPickStep(ColorScheme cs, AppLocalizations l10n) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '${l10n.search} (${l10n.nameLabel} / ${l10n.phone})...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _searchMembers('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
            onChanged: (val) {
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 280),
                () => _searchMembers(val),
              );
            },
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
              ? Center(
                  child: Text(
                    l10n.noMembersFound,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final m = _searchResults[index];
                    final name =
                        (m['full_name'] as String?)?.trim().isNotEmpty == true
                        ? m['full_name'] as String
                        : l10n.unnamed;
                    final email = m['email'] as String? ?? '';
                    final phone = m['phone'] as String? ?? '';
                    final role = m['role'] as String? ?? 'customer';
                    final isAdmin = _isAdminRoleOrType(
                      role,
                      m['user_type'] as String?,
                    );
                    final badgeColor = isAdmin
                        ? const Color(0xFF5B3DF0)
                        : cs.primary;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        onTap: () => _pickMember(m),
                        leading: CircleAvatar(
                          backgroundColor: badgeColor.withValues(alpha: 0.14),
                          child: Text(
                            safeInitialFrom([name, email, phone]),
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (email.isNotEmpty) email,
                            if (phone.isNotEmpty) phone,
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _roleBadgeText(role, l10n),
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildConfigureMemberStep(
    ColorScheme cs,
    String lang,
    AppLocalizations l10n,
  ) {
    final member = _selectedMember!;
    final name = (member['full_name'] as String?)?.trim().isNotEmpty == true
        ? member['full_name'] as String
        : l10n.unnamed;
    final email = member['email'] as String? ?? '';
    final phone = member['phone'] as String? ?? '';
    final currentRole = member['role'] as String? ?? 'customer';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF5B3DF0)
                      .withValues(alpha: 0.14),
                  child: Text(
                    safeInitialFrom([name, email, phone]),
                    style: const TextStyle(
                      color: Color(0xFF5B3DF0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (email.isNotEmpty) email,
                          if (phone.isNotEmpty) phone,
                          '${l10n.adminRole}: ${_roleBadgeText(currentRole, l10n)}',
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedMember = null),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(l10n.selectRecipient),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.adminRole,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kSelectableAdminRoles.map((item) {
              final selected = _selectedRole == item.role;
              return ChoiceChip(
                avatar: Icon(
                  item.icon,
                  size: 16,
                  color: selected ? cs.onPrimary : const Color(0xFF5B3DF0),
                ),
                label: Text(_roleBadgeText(item.role, l10n)),
                selected: selected,
                selectedColor: const Color(0xFF5B3DF0),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : cs.onSurface,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) {
                  setState(() => _selectedRole = item.role);
                },
              );
            }).toList(),
          ),
          if (_selectedRole != 'customer') ...[
            const SizedBox(height: 18),
            Text(
              l10n.assignRegion,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final picked = await RegionPickerSheet.show(
                  context,
                  selectedRegionId: _selectedRegionId,
                );
                if (picked != null && mounted) {
                  setState(() {
                    _selectedRegionId = picked.id;
                    _selectedRegionName = picked.displayName(lang);
                  });
                }
              },
              icon: const Icon(Icons.location_on_rounded),
              label: Text(
                _selectedRegionName ??
                    (_selectedRegionId != null
                        ? '${l10n.regions}: $_selectedRegionId'
                        : l10n.adminMgmtSelectRegion),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.permissionDelegation,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedPermissions.length ==
                          _kGranularPlatformPermissionCodes.length) {
                        _selectedPermissions.clear();
                      } else {
                        _selectedPermissions.addAll(
                          _kGranularPlatformPermissionCodes,
                        );
                      }
                    });
                  },
                  child: Text(
                    _selectedPermissions.length ==
                            _kGranularPlatformPermissionCodes.length
                        ? l10n.clear
                        : l10n.allRoles,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingPermissions)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kGranularPlatformPermissionCodes.map((code) {
                  final isSelected = _selectedPermissions.contains(code);
                  return FilterChip(
                    label: Text(_permissionLabel(code, l10n)),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedPermissions.add(code);
                        } else {
                          _selectedPermissions.remove(code);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5B3DF0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isSaving ? null : _saveConfiguration,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              l10n.save,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
