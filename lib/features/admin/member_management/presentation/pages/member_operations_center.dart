import 'package:delwaqty/core/utils/avatar_initial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/features/admin/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/admin/member_management/presentation/member_providers.dart';
import 'package:delwaqty/features/admin/member_management/presentation/pages/member_drawer.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

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
                  icon: Icons.verified_user_rounded,
                  label: l10n.adminVerifications,
                  color: const Color(0xFF34C759),
                  onTap: () => context.push('/admin/verifications'),
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
        Container(
          width: 1,
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
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
    final filters = {
      'search': _search,
      'role': _roleFilter,
      'userType': null,
      'accountStatus': _accountStatusFilter,
      'verificationStatus': _verificationStatusFilter,
      'serviceCategory': _serviceCategoryFilter,
      'sanctionStatus': _sanctionStatusFilter,
      'sort': _sortBy ?? 'newest',
      'limit': _limit,
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
                  label: l10n.active,
                  selected: _accountStatusFilter == 'active',
                  onTap: () {
                    setState(() {
                      _accountStatusFilter =
                          _accountStatusFilter == 'active' ? null : 'active';
                    });
                    _applyFilters();
                  },
                ),
                _FilterChipWidget(
                  label: l10n.suspended,
                  selected: _accountStatusFilter == 'suspended',
                  onTap: () {
                    setState(() {
                      _accountStatusFilter =
                          _accountStatusFilter == 'suspended' ? null : 'suspended';
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
              DropdownMenuItem(
                value: 'newest',
                child: Text(l10n.newest),
              ),
              DropdownMenuItem(
                value: 'oldest',
                child: Text(l10n.oldest),
              ),
              DropdownMenuItem(
                value: 'name',
                child: Text(l10n.nameLabel),
              ),
              DropdownMenuItem(
                value: 'orders',
                child: Text(l10n.orders),
              ),
              DropdownMenuItem(
                value: 'wallet',
                child: Text(l10n.wallet),
              ),
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
              final members = ref.watch(memberOpsProvider);
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        margin: const EdgeInsets.only(right: 6),
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
      'admin' => const Color(0xFF5B3DF0),
      'driver' => const Color(0xFF007AFF),
      'merchant' => const Color(0xFFFF9500),
      'customer' => const Color(0xFF00C7BE),
      _ => Colors.blueGrey,
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
                          border: Border.all(
                            color: cs.surface,
                            width: 2,
                          ),
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
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
                        _accountStatusLabel(l10n, member.accountStatus ?? 'active'),
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
        margin: const EdgeInsets.only(right: 8),
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
