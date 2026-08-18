import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/member_management/presentation/member_providers.dart';
import 'package:delwaqty/features/member_management/presentation/pages/member_drawer.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 728;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Operations Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(memberOpsProvider);
              ref.invalidate(memberOpsCountProvider);
            },
          ),
        ],
      ),
      body: isDesktop
          ? _DesktopLayout(
              selectedMemberId: _selectedMemberId,
              onSelectMember: _selectMember,
            )
          : _MobileLayout(
              selectedMemberId: _selectedMemberId,
              onSelectMember: _selectMember,
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
                        'Select a member to view details',
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(memberOpsProvider.notifier);

    void applyFilters() {
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
      notifier.setFilters(filters);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.search,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
            onSubmitted: (_) => applyFilters(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipWidget(
                  label: 'All Roles',
                  selected: _roleFilter == null,
                  onTap: () => setState(() => _roleFilter = null),
                ),
                _FilterChipWidget(
                  label: 'Customer',
                  selected: _roleFilter == 'customer',
                  onTap: () => setState(() => _roleFilter = 'customer'),
                ),
                _FilterChipWidget(
                  label: 'Driver',
                  selected: _roleFilter == 'driver',
                  onTap: () => setState(() => _roleFilter = 'driver'),
                ),
                _FilterChipWidget(
                  label: 'Merchant',
                  selected: _roleFilter == 'merchant',
                  onTap: () => setState(() => _roleFilter = 'merchant'),
                ),
                _FilterChipWidget(
                  label: 'Active',
                  selected: _accountStatusFilter == 'active',
                  onTap: () => setState(() {
                    _accountStatusFilter =
                        _accountStatusFilter == 'active' ? null : 'active';
                  }),
                ),
                _FilterChipWidget(
                  label: 'Suspended',
                  selected: _accountStatusFilter == 'suspended',
                  onTap: () => setState(() {
                    _accountStatusFilter =
                        _accountStatusFilter == 'suspended' ? null : 'suspended';
                  }),
                ),
                _FilterChipWidget(
                  label: 'Unverified',
                  selected: _verificationStatusFilter == 'unverified',
                  onTap: () => setState(() {
                    _verificationStatusFilter =
                        _verificationStatusFilter == 'unverified'
                            ? null
                            : 'unverified';
                  }),
                ),
                _FilterChipWidget(
                  label: 'Verified',
                  selected: _verificationStatusFilter == 'verified',
                  onTap: () => setState(() {
                    _verificationStatusFilter =
                        _verificationStatusFilter == 'verified'
                            ? null
                            : 'verified';
                  }),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: DropdownButtonFormField<String>(
            initialValue: _sortBy,
            decoration: InputDecoration(
              labelText: l10n.sortBy,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: 'newest',
                child: Text('Newest'),
              ),
              DropdownMenuItem(
                value: 'oldest',
                child: Text('Oldest'),
              ),
              DropdownMenuItem(
                value: 'name',
                child: Text('Name'),
              ),
              DropdownMenuItem(
                value: 'orders',
                child: Text('Orders'),
              ),
              DropdownMenuItem(
                value: 'wallet',
                child: Text('Wallet'),
              ),
            ],
            onChanged: (value) => setState(() => _sortBy = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: applyFilters,
              child: const Text('Apply Filters'),
            ),
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final members = ref.watch(memberOpsProvider);
              final notifier = ref.read(memberOpsProvider.notifier);
              if (members.isEmpty) {
                if (notifier.lastError != null) {
                  return PremiumEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Failed to load members',
                    message: '${notifier.lastError}',
                    actionLabel: 'Retry',
                    onAction: () => notifier.refresh(),
                  );
                }
                return const PremiumEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No members found',
                  message: 'Try adjusting your search or filters.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
    final statusColor = switch (member.accountStatus) {
      'active' => Colors.green,
      'restricted' => Colors.orange,
      'suspended' => Colors.red,
      'banned' => Colors.red.shade900,
      _ => Colors.grey,
    };
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isSelected
          ? cs.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Text(
            (member.fullName ?? member.email ?? member.username ?? '?')
                .substring(0, 1)
                .toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          member.fullName ?? 'Unnamed',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          '${member.email ?? ''}  ·  ${member.role}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            member.accountStatus ?? 'active',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}
