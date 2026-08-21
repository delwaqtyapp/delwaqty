import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/admin/member_management/domain/entities/member.dart';
import 'package:delwaqty/features/admin/member_management/presentation/member_providers.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

class MemberListPage extends ConsumerStatefulWidget {
  const MemberListPage({super.key, this.onMemberSelected});

  final ValueChanged<String>? onMemberSelected;

  @override
  ConsumerState<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends ConsumerState<MemberListPage> {
  String _search = '';
  String? _roleFilter;
  String? _accountStatusFilter;
  String? _verificationStatusFilter;
  String? _sortBy;
  String? _serviceCategoryFilter;
  String? _sanctionStatusFilter;
  final int _limit = 25;
  final int _offset = 0;

  void _applyFilters() {
    final notifier = ref.read(memberOpsProvider.notifier);
    notifier.setFilters({
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(memberOpsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search members...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (v) => setState(() => _search = v),
            onSubmitted: (_) => _applyFilters(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All Roles',
                  selected: _roleFilter == null,
                  onTap: () => setState(() => _roleFilter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Customer',
                  selected: _roleFilter == 'customer',
                  onTap: () => setState(() => _roleFilter = 'customer'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Driver',
                  selected: _roleFilter == 'driver',
                  onTap: () => setState(() => _roleFilter = 'driver'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Merchant',
                  selected: _roleFilter == 'merchant',
                  onTap: () => setState(() => _roleFilter = 'merchant'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Provider',
                  selected: _roleFilter == 'provider',
                  onTap: () => setState(() => _roleFilter = 'provider'),
                ),
                const SizedBox(width: 16),
                _FilterChip(
                  label: 'Active',
                  selected: _accountStatusFilter == 'active',
                  onTap: () => setState(() => _accountStatusFilter = 'active'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Suspended',
                  selected: _accountStatusFilter == 'suspended',
                  onTap: () => setState(() => _accountStatusFilter = 'suspended'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  decoration: InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(value: 'orders', child: Text('Orders')),
                    DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                  ],
                  onChanged: (value) => setState(() => _sortBy = value),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyFilters,
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: members.isEmpty
              ? const PremiumEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No members found',
                  message: 'Try adjusting your search or filters.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _MemberTile(
                      member: member,
                      onTap: () {
                        if (widget.onMemberSelected != null) {
                          widget.onMemberSelected!(member.id);
                        } else {
                          context.push('/admin/members/${member.id}');
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

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

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onTap});

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
          backgroundColor: statusColor.withAlpha(38),
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
        title: Text(
          member.fullName ?? 'Unnamed',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Row(
          children: [
            if (member.regionLabel != null) ...[
              Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  member.regionLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ] else
              Text(
                member.email ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(31),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            member.accountStatus ?? 'active',
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
