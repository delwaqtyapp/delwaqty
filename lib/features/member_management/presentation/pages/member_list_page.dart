import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/member_management/presentation/member_providers.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MemberListPage extends ConsumerWidget {
  const MemberListPage({super.key});

  @override
  ConsumerState<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends ConsumerState<MemberListPage> {
  // Filters
  String _search = '';
  String? _roleFilter;
  String? _accountStatusFilter;
  String? _verificationStatusFilter;
  String? _sortBy;
  String? _serviceCategoryFilter;
  String? _sanctionStatusFilter;
  int _limit = 25;
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(memberOpsProvider.notifier);

    // Apply filters when called
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
      notifier.setFilters(filters);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                _FilterChip(
                  label: 'All Roles',
                  selected: _roleFilter == null,
                  onTap: () => setState(() => _roleFilter = null),
                ),
                _FilterChip(
                  label: 'Customer',
                  selected: _roleFilter == 'customer',
                  onTap: () => setState(() => _roleFilter = 'customer'),
                ),
                _FilterChip(
                  label: 'Driver',
                  selected: _roleFilter == 'driver',
                  onTap: () => setState(() => _roleFilter = 'driver'),
                ),
                _FilterChip(
                  label: 'Merchant',
                  selected: _roleFilter == 'merchant',
                  onTap: () => setState(() => _roleFilter = 'merchant'),
                ),
                _FilterChip(
                  label: 'Active',
                  selected: _accountStatusFilter == 'active',
                  onTap: () => setState(() => _accountStatusFilter = 'active'),
                ),
                _FilterChip(
                  label: 'Suspended',
                  selected: _accountStatusFilter == 'suspended',
                  onTap: () => setState(() => _accountStatusFilter = 'suspended'),
                ),
                _FilterChip(
                  label: 'Unverified',
                  selected: _verificationStatusFilter == 'unverified',
                  onTap: () => setState(() => _verificationStatusFilter = 'unverified'),
                ),
                _FilterChip(
                  label: 'Verified',
                  selected: _verificationStatusFilter == 'verified',
                  onTap: () => setState(() => _verificationStatusFilter = 'verified'),
                ),
              ],
            ),
          ),
          // Sort dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: InputDecoration(
                labelText: l10n.sortBy,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: 'newest',
                  child: Text(l10n.sortNewest),
                ),
                DropdownMenuItem(
                    value: 'oldest',
                    child: Text(l10n.sortOldest),
                  ),
                DropdownMenuItem(
                    value: 'name',
                    child: Text(l10n.sortName),
                  ),
                DropdownMenuItem(
                  value: 'orders',
                  child: Text(l10n.sortOrders),
                ),
                DropdownMenuItem(
                  value: 'wallet',
                  child: Text(l10n.sortWallet),
                ),
              ],
              onChanged: (value) => setState(() => _sortBy = value),
            ),
          ),
          // Apply button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _applyFilters,
              child: Text(l10n.applyFilters),
            ),
          ),
          // Member list
          Expanded(
            child: ref.watch(memberOpsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline,
                title: l10n.error,
                message: e.toString(),
              ),
              data: (members) {
                if (members.isEmpty) {
                  return const PremiumEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No members found',
                    message: 'Try adjusting your search or filters.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _MemberTile(
                      member: member,
                      onTap: () => context.push('/admin/members/${member.id}'),
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
}

// Helper widget for filter chips
class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
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

// Helper widget for region badge inside member tile
class _RegionBadge extends StatelessWidget {
  const _RegionBadge({
    required this.regionLabel,
  });

  final String? regionLabel;

  @override
  Widget build(BuildContext context) {
    if (regionLabel == null || regionLabel!.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Chip(
        label: Text(regionLabel!),
        labelStyle: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// Compact member tile with region badge and status color
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.onTap,
  });

  final Member member;
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Text(
            (member.fullName ?? member.email ?? member.username ?? '?')
                .substring(0, 1)
                .toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.fullName ?? 'Unnamed',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (member.regionLabel != null)
              _RegionBadge(regionLabel: member.regionLabel),
          ],
        ),
        subtitle: Text(
          '${member.email ?? ''}  •  ${member.role}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            member.accountStatus,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}