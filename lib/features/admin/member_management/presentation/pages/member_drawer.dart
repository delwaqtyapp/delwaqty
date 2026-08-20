import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/member_management/presentation/member_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/shared/widgets/stat_card.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/core/constants/app_constants.dart';

class MemberDrawer extends ConsumerWidget {
  const MemberDrawer({
    super.key,
    required this.memberId,
    this.onDismiss,
  });

  final String memberId;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(memberOpsProfileProvider(memberId));
    final l10n = AppLocalizations.of(context);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => PremiumEmptyState(
        icon: Icons.error_outline,
        title: l10n.error,
        message: e.toString(),
      ),
      data: (profile) {
        if (profile == null) {
          return PremiumEmptyState(
            icon: Icons.person_off_rounded,
            title: l10n.memberNotFound,
            message: l10n.memberNotFoundMessage,
          );
        }
        final adapted = normalizeMemberOpsProfile(profile);
        final permissions =
            (adapted['permissions'] as Map<String, dynamic>?) ?? {};
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _DrawerHeader(
                profile: adapted,
                onDismiss: onDismiss,
              ),
            ),
            const SliverToBoxAdapter(
              child: _OverviewSection(),
            ),
            SliverToBoxAdapter(
              child: _IdentitySection(profile: adapted),
            ),
            SliverToBoxAdapter(
              child: _VerificationSection(
                memberId: memberId,
                permissions: permissions,
              ),
            ),
            SliverToBoxAdapter(
              child: _LocationSection(profile: adapted),
            ),
            SliverToBoxAdapter(
              child: _ActivityTimelineSection(memberId: memberId),
            ),
            SliverToBoxAdapter(
              child: _OrdersSection(
                profile: adapted,
                memberId: memberId,
              ),
            ),
            SliverToBoxAdapter(
              child: _ServicesSection(profile: adapted),
            ),
            SliverToBoxAdapter(
              child: _WalletFinancialsSection(memberId: memberId),
            ),
            SliverToBoxAdapter(
              child: _EarningsCommissionsSection(memberId: memberId),
            ),
            SliverToBoxAdapter(
              child: _ComplaintsSection(
                memberId: memberId,
                permissions: permissions,
              ),
            ),
            SliverToBoxAdapter(
              child: _SupportSection(memberId: memberId),
            ),
            SliverToBoxAdapter(
              child: _SanctionsSection(
                memberId: memberId,
                permissions: permissions,
              ),
            ),
            SliverToBoxAdapter(
              child: _DocumentsSection(profile: adapted),
            ),
            SliverToBoxAdapter(
              child: _AdminActionsSection(
                memberId: memberId,
                profile: adapted,
                permissions: permissions,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        );
      },
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.profile,
    this.onDismiss,
  });

  final Map<String, dynamic> profile;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final basic = profile['basic'] as Map<String, dynamic>? ?? {};
    final region = profile['region'] as Map<String, dynamic>? ?? {};
    final name = basic['full_name'] as String? ?? l10n.unnamed;
    final email = basic['email'] as String? ?? '';
    final role = basic['role'] as String? ?? 'customer';
    final accountStatus = basic['account_status'] as String? ?? 'active';
    final verificationStatus =
        basic['verification_status'] as String? ?? 'unverified';
    final avatarUrl = basic['avatar_url'] as String?;
    final isOnline = basic['is_online'] as bool? ?? false;
    final lastSeenAt = basic['last_seen_at'] as String?;
    final regionLabel = region['hierarchical_label'] as String?;

    final statusColor = switch (accountStatus) {
      'active' => Colors.green,
      'restricted' => Colors.orange,
      'suspended' => Colors.red,
      'banned' => Colors.red.shade900,
      _ => Colors.grey,
    };

    final verificationColor = switch (verificationStatus) {
      'verified' => Colors.green,
      'pending' => Colors.orange,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 22,
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(
                label: role,
                color: cs.primary,
              ),
              _Badge(
                label: accountStatus,
                color: statusColor,
              ),
              _Badge(
                label: verificationStatus,
                color: verificationColor,
              ),
              if (isOnline)
                _Badge(
                  label: l10n.onlineBadge,
                  color: Colors.green,
                ),
            ],
          ),
          if (regionLabel != null && regionLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    regionLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (lastSeenAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.lastSeenLabel(lastSeenAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final basic = profile['basic'] as Map<String, dynamic>? ?? {};
    final fullName = basic['full_name'] as String? ?? '-';
    final username = basic['username'] as String? ?? '-';
    final email = basic['email'] as String? ?? '-';
    final phone = basic['phone'] as String? ?? '-';
    final dob = basic['date_of_birth'] as String? ?? '-';
    final avatarUrl = basic['avatar_url'] as String? ?? '-';
    final idCardUrl = basic['id_card_url'] as String?;
    final tradeLicenseUrl = basic['trade_license_url'] as String?;
    final drivingLicenseUrl = basic['driving_license_url'] as String?;
    final userType = basic['user_type'] as String? ?? '-';
    final role = basic['role'] as String? ?? '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.badge_outlined, size: 20),
        title: Text(l10n.identitySection),
        children: [
          _InfoTile(label: l10n.fullName, value: fullName, icon: Icons.person_outline),
          _InfoTile(label: l10n.username, value: username, icon: Icons.alternate_email),
          _InfoTile(label: l10n.email, value: email, icon: Icons.email_outlined),
          _InfoTile(label: l10n.phone, value: phone, icon: Icons.phone_outlined),
          _InfoTile(label: l10n.dateOfBirth, value: dob, icon: Icons.cake_outlined),
          _InfoTile(label: l10n.role, value: role),
          _InfoTile(label: l10n.userTypeLabel, value: userType),
          _InfoTile(label: l10n.avatarUrl, value: avatarUrl),
          if (idCardUrl != null)
            _InfoTile(label: l10n.idCard, value: idCardUrl, icon: Icons.credit_card),
          if (tradeLicenseUrl != null)
            _InfoTile(
              label: l10n.tradeLicense,
              value: tradeLicenseUrl,
              icon: Icons.business_center_outlined,
            ),
          if (drivingLicenseUrl != null)
            _InfoTile(
              label: l10n.drivingLicense,
              value: drivingLicenseUrl,
              icon: Icons.drive_eta_outlined,
            ),
        ],
      ),
    );
  }
}

class _VerificationSection extends ConsumerWidget {
  const _VerificationSection({
    required this.memberId,
    required this.permissions,
  });

  final String memberId;
  final Map<String, dynamic> permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final verificationAsync = ref.watch(memberVerificationProvider(memberId));
    final canDecideVerification =
        permissions['can_decide_verification'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.verified_user_outlined, size: 20),
        title: Text(l10n.verificationSection),
        children: [
          verificationAsync.when(
            loading: () => const ShimmerLoading(
              child: SizedBox(height: 60),
            ),
            error: (e, _) => Text(
              l10n.failedToLoad,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (attempt) {
              if (attempt == null) {
                return _InfoTile(
                  label: l10n.status,
                  value: l10n.noVerificationAttempts,
                );
              }
              final status = attempt['status'] as String? ?? 'pending';
              final attemptsCount =
                  (attempt['attempts_count'] as num?)?.toInt() ?? 0;
              final rejectionReason =
                  attempt['rejection_reason'] as String?;
              final reviewedBy = attempt['reviewed_by'] as String?;
              final createdAt = attempt['created_at'] as String? ?? '-';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoTile(label: l10n.status, value: status),
                  _InfoTile(
                    label: l10n.attempts,
                    value: attemptsCount.toString(),
                  ),
                  _InfoTile(label: l10n.submitted, value: createdAt),
                  if (reviewedBy != null && reviewedBy.isNotEmpty)
                    _InfoTile(label: l10n.reviewedBy, value: reviewedBy),
                  if (rejectionReason != null && rejectionReason.isNotEmpty)
                    _InfoTile(
                      label: l10n.rejectionReason,
                      value: rejectionReason,
                      icon: Icons.info_outline,
                    ),
                  if (canDecideVerification) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showVerificationDecision(context, ref, true),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text(l10n.approve),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showVerificationDecision(context, ref, false),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: Text(l10n.reject),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showVerificationDecision(
    BuildContext context,
    WidgetRef ref,
    bool approve,
  ) async {
    final l10n = AppLocalizations.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(
            approve ? l10n.approveVerification : l10n.rejectVerification,
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.reason,
              hintText: approve
                  ? l10n.approvalNote
                  : l10n.rejectionReasonRequired,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(approve ? l10n.approve : l10n.reject),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    if (!approve && reason.trim().isEmpty) return;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? l10n.verificationApproved : l10n.verificationRejected,
          ),
        ),
      );
      ref.invalidate(memberVerificationProvider(memberId));
      ref.invalidate(memberOpsProfileProvider(memberId));
    }
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final region = profile['region'] as Map<String, dynamic>? ?? {};
    final location = profile['location'] as Map<String, dynamic>? ?? {};
    final hierarchicalLabel = region['hierarchical_label'] as String? ?? '-';
    final governorate = region['governorate'] as String? ?? '-';
    final city = region['city'] as String? ?? '-';
    final latitude = location['latitude'] as num?;
    final longitude = location['longitude'] as num?;
    final lastLocationUpdate = location['updated_at'] as String?;
    final basic = profile['basic'] as Map<String, dynamic>? ?? {};
    final lastSeenAt = basic['last_seen_at'] as String? ?? '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.location_on_outlined, size: 20),
        title: Text(l10n.locationSection),
        children: [
          _InfoTile(label: l10n.region, value: hierarchicalLabel, icon: Icons.map_outlined),
          _InfoTile(label: l10n.governorate, value: governorate),
          _InfoTile(label: l10n.city, value: city),
          if (latitude != null && longitude != null)
            _InfoTile(
              label: l10n.coordinates,
              value: '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              icon: Icons.my_location,
            ),
          if (lastLocationUpdate != null)
            _InfoTile(label: l10n.lastLocationUpdate, value: lastLocationUpdate),
          _InfoTile(label: l10n.lastSeen, value: lastSeenAt, icon: Icons.access_time),
        ],
      ),
    );
  }
}

class _ActivityTimelineSection extends ConsumerWidget {
  const _ActivityTimelineSection({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final timelineAsync = ref.watch(memberTimelineProvider(memberId));
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.timeline_outlined, size: 20),
        title: Text(l10n.activityTimelineSection),
        children: [
          timelineAsync.when(
            loading: () => const ShimmerLoading(
              child: SizedBox(height: 120),
            ),
            error: (e, _) => Text(
              l10n.failedToLoadTimeline,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (events) {
              if (events.isEmpty) {
                return Text(
                  l10n.noEventsYet,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                );
              }
              return Column(
                children: events.take(20).map((e) {
                  final type = e['event_type'] as String? ?? '?';
                  final createdAt = e['created_at'] as String? ?? '';
                  final detail =
                      e['detail'] as Map<String, dynamic>? ?? {};
                  final description =
                      detail['description'] as String? ??
                      detail['reason'] as String? ??
                      '';
                  return _TimelineEventTile(
                    type: type,
                    description: description,
                    timestamp: createdAt,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({
    required this.type,
    required this.description,
    required this.timestamp,
  });

  final String type;
  final String description;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _eventIcon(type);
    final color = _eventColor(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  timestamp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('sanction')) return Icons.gavel_rounded;
    if (t.contains('ban')) return Icons.block;
    if (t.contains('reward')) return Icons.card_giftcard_rounded;
    if (t.contains('order')) return Icons.receipt_long_rounded;
    if (t.contains('complaint')) return Icons.warning_amber_rounded;
    if (t.contains('wallet') || t.contains('transaction')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (t.contains('verification')) return Icons.verified_user_outlined;
    if (t.contains('registration') || t.contains('register')) {
      return Icons.person_add_rounded;
    }
    if (t.contains('profile')) return Icons.person_outline;
    if (t.contains('admin')) return Icons.admin_panel_settings_outlined;
    return Icons.circle;
  }

  Color _eventColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('ban')) return Colors.red;
    if (t.contains('sanction')) return Colors.orange;
    if (t.contains('reward')) return Colors.green;
    if (t.contains('order')) return Colors.blue;
    if (t.contains('complaint')) return Colors.amber;
    if (t.contains('wallet') || t.contains('transaction')) {
      return Colors.teal;
    }
    if (t.contains('verification')) return Colors.purple;
    return Colors.grey;
  }
}

class _OrdersSection extends ConsumerWidget {
  const _OrdersSection({
    required this.profile,
    required this.memberId,
  });

  final Map<String, dynamic> profile;
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final basic = profile['basic'] as Map<String, dynamic>? ?? {};
    final role = basic['role'] as String? ?? 'customer';
    final financials = profile['financials'] as Map<String, dynamic>? ?? {};
    final ordersCount = (financials['orders_count'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.receipt_long_rounded, size: 20),
        title: Text(_sectionTitle(l10n, role)),
        children: [
          ref.watch(memberOrdersProvider(memberId)).when(
            loading: () => const ShimmerLoading(
              child: SizedBox(height: 100),
            ),
            error: (e, _) => Text(
              l10n.failedToLoad,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (orders) {
              if (orders.isEmpty) {
                return Text(
                  l10n.noOrdersFound,
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final completed = orders
                  .where((o) => o['status'] == 'completed')
                  .length;
              final cancelled = orders
                  .where((o) => o['status'] == 'cancelled')
                  .length;
              final pending = orders
                  .where((o) => o['status'] == 'pending')
                  .length;
              final totalSpending = orders.fold<double>(
                0,
                (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0),
              );
              return Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatCard(
                        title: l10n.total,
                        value: ordersCount.toString(),
                        icon: Icons.receipt_long_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      StatCard(
                        title: l10n.completed,
                        value: completed.toString(),
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      StatCard(
                        title: l10n.cancelled,
                        value: cancelled.toString(),
                        icon: Icons.cancel_outlined,
                        color: Colors.red,
                      ),
                      StatCard(
                        title: l10n.pending,
                        value: pending.toString(),
                        icon: Icons.pending_outlined,
                        color: Colors.orange,
                      ),
                      StatCard(
                        title: l10n.totalSpending,
                        value: totalSpending.toStringAsFixed(2),
                        icon: Icons.payments_outlined,
                        color: Colors.teal,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _sectionTitle(AppLocalizations l10n, String role) {
    return switch (role) {
      'driver' => l10n.deliveriesSection,
      'merchant' => l10n.merchantOrdersSection,
      'provider' => l10n.jobsSection,
      _ => l10n.ordersRequestsSection,
    };
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = profile['services'] as Map<String, dynamic>? ?? {};
    final categories = services['categories'] as List? ?? [];
    final serviceArea = services['service_area'] as String? ?? '-';
    final rating = services['rating'] as num?;
    final responseRate = services['response_rate'] as num?;
    final completionRate = services['completion_rate'] as num?;
    final completedCount = (services['completed_count'] as num?)?.toInt() ?? 0;
    final cancelledCount = (services['cancelled_count'] as num?)?.toInt() ?? 0;
    final basic = profile['basic'] as Map<String, dynamic>? ?? {};
    final role = basic['role'] as String? ?? 'customer';

    if (role != 'provider' && role != 'merchant') {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.build_outlined, size: 20),
        title: Text(l10n.servicesSection),
        children: [
          if (categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: categories.map((c) {
                  return Chip(
                    label: Text(
                      c.toString(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatCard(
                title: l10n.completed,
                value: completedCount.toString(),
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
              StatCard(
                title: l10n.cancelled,
                value: cancelledCount.toString(),
                icon: Icons.cancel_outlined,
                color: Colors.red,
              ),
              if (rating != null)
                StatCard(
                  title: l10n.rating,
                  value: rating.toStringAsFixed(1),
                  icon: Icons.star_outline_rounded,
                  color: Colors.amber,
                ),
              if (responseRate != null)
                StatCard(
                  title: l10n.responseRate,
                  value: '${(responseRate * 100).toStringAsFixed(0)}%',
                  icon: Icons.speed_outlined,
                  color: Colors.blue,
                ),
              if (completionRate != null)
                StatCard(
                  title: l10n.completionRate,
                  value: '${(completionRate * 100).toStringAsFixed(0)}%',
                  icon: Icons.done_all_rounded,
                  color: Colors.teal,
                ),
            ],
          ),
          if (serviceArea != '-')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _InfoTile(
                label: l10n.serviceArea,
                value: serviceArea,
                icon: Icons.map_outlined,
              ),
            ),
        ],
      ),
    );
  }
}

class _WalletFinancialsSection extends ConsumerWidget {
  const _WalletFinancialsSection({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final financialAsync = ref.watch(memberFinancialSummaryProvider(memberId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.account_balance_wallet_outlined, size: 20),
        title: Text(l10n.walletFinancialsSection),
        children: [
          financialAsync.when(
            loading: () => const ShimmerLoading(
              child: SizedBox(height: 120),
            ),
            error: (e, _) => Text(
              l10n.failedToLoadFinancials,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (data) {
              if (data == null) {
                return Text(
                  l10n.noFinancialData,
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final wallet = data['wallet'] as Map<String, dynamic>? ?? {};
              final balance =
                  (wallet['balance'] as num?)?.toDouble() ?? 0;
              final available =
                  (wallet['available'] as num?)?.toDouble() ?? 0;
              final pending =
                  (wallet['pending'] as num?)?.toDouble() ?? 0;
              final totalEarned =
                  (data['total_earned'] as num?)?.toDouble() ?? 0;
              final totalWithdrawn =
                  (data['total_withdrawn'] as num?)?.toDouble() ?? 0;
              final totalCommissions =
                  (data['total_commissions'] as num?)?.toDouble() ?? 0;
              final totalRefunds =
                  (data['total_refunds'] as num?)?.toDouble() ?? 0;
              final transactions =
                  data['recent_transactions'] as List? ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatCard(
                        title: l10n.balance,
                        value: balance.toStringAsFixed(2),
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.green,
                      ),
                      StatCard(
                        title: l10n.availableStat,
                        value: available.toStringAsFixed(2),
                        icon: Icons.check_circle_outline,
                        color: Colors.teal,
                      ),
                      StatCard(
                        title: l10n.pending,
                        value: pending.toStringAsFixed(2),
                        icon: Icons.pending_outlined,
                        color: Colors.orange,
                      ),
                      StatCard(
                        title: l10n.totalEarned,
                        value: totalEarned.toStringAsFixed(2),
                        icon: Icons.trending_up_rounded,
                        color: Colors.blue,
                      ),
                      StatCard(
                        title: l10n.withdrawnStat,
                        value: totalWithdrawn.toStringAsFixed(2),
                        icon: Icons.money_off_rounded,
                        color: Colors.purple,
                      ),
                      StatCard(
                        title: l10n.commissionsStat,
                        value: totalCommissions.toStringAsFixed(2),
                        icon: Icons.receipt_long_rounded,
                        color: Colors.amber,
                      ),
                      StatCard(
                        title: l10n.refunds,
                        value: totalRefunds.toStringAsFixed(2),
                        icon: Icons.replay_rounded,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  if (transactions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.recentTransactions,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...transactions.take(10).map((t) {
                      final txType = t['type'] as String? ?? 'unknown';
                      final amount = (t['amount'] as num?)?.toDouble() ?? 0;
                      final txTimestamp = t['created_at'] as String? ?? '';
                      final source = t['source'] as String? ?? '';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _txIcon(txType),
                          size: 16,
                          color: _txColor(txType),
                        ),
                        title: Text(
                          '$txType â€” $amount',
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '$source $txTimestamp',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _txIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('credit') || t.contains('earned')) {
      return Icons.arrow_downward_rounded;
    }
    if (t.contains('debit') || t.contains('withdraw')) {
      return Icons.arrow_upward_rounded;
    }
    if (t.contains('commission')) return Icons.receipt_long_rounded;
    if (t.contains('refund')) return Icons.replay_rounded;
    return Icons.circle;
  }

  Color _txColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('credit') || t.contains('earned')) return Colors.green;
    if (t.contains('debit') || t.contains('withdraw')) return Colors.red;
    if (t.contains('commission')) return Colors.amber;
    if (t.contains('refund')) return Colors.orange;
    return Colors.grey;
  }
}

class _EarningsCommissionsSection extends ConsumerWidget {
  const _EarningsCommissionsSection({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final financialAsync = ref.watch(memberFinancialSummaryProvider(memberId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.payments_outlined, size: 20),
        title: Text(l10n.earningsCommissionsSection),
        children: [
          financialAsync.when(
            loading: () => const ShimmerLoading(
              child: SizedBox(height: 80),
            ),
            error: (e, _) => Text(
              l10n.failedToLoad,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (data) {
              if (data == null) {
                return Text(
                  l10n.noEarningsData,
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final grossEarnings =
                  (data['gross_earnings'] as num?)?.toDouble() ?? 0;
              final commissionRate =
                  (data['commission_rate'] as num?)?.toDouble() ?? 0;
              final commissionAmount =
                  (data['commission_amount'] as num?)?.toDouble() ?? 0;
              final netEarnings =
                  (data['net_earnings'] as num?)?.toDouble() ?? 0;
              final pendingEarnings =
                  (data['pending_earnings'] as num?)?.toDouble() ?? 0;
              final paidEarnings =
                  (data['paid_earnings'] as num?)?.toDouble() ?? 0;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatCard(
                    title: l10n.grossEarnings,
                    value: grossEarnings.toStringAsFixed(2),
                    icon: Icons.trending_up_rounded,
                    color: Colors.blue,
                  ),
                  StatCard(
                    title: l10n.commissionRate,
                    value: '${(commissionRate * 100).toStringAsFixed(0)}%',
                    icon: Icons.percent_rounded,
                    color: Colors.amber,
                  ),
                  StatCard(
                    title: l10n.commissionLabel,
                    value: commissionAmount.toStringAsFixed(2),
                    icon: Icons.receipt_long_rounded,
                    color: Colors.orange,
                  ),
                  StatCard(
                    title: l10n.netEarnings,
                    value: netEarnings.toStringAsFixed(2),
                    icon: Icons.account_balance_rounded,
                    color: Colors.green,
                  ),
                  StatCard(
                    title: l10n.pending,
                    value: pendingEarnings.toStringAsFixed(2),
                    icon: Icons.pending_outlined,
                    color: Colors.orange,
                  ),
                  StatCard(
                    title: l10n.paid,
                    value: paidEarnings.toStringAsFixed(2),
                    icon: Icons.check_circle_outline,
                    color: Colors.teal,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ComplaintsSection extends ConsumerWidget {
  const _ComplaintsSection({
    required this.memberId,
    required this.permissions,
  });

  final String memberId;
  final Map<String, dynamic> permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final complaintsAsync = ref.watch(memberComplaintsProvider(memberId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.warning_amber_rounded, size: 20),
        title: Text(l10n.complaintsSection),
        children: [
          complaintsAsync.when(
            loading: () => const ShimmerLoading(
              child: SizedBox(height: 100),
            ),
            error: (e, _) => Text(
              l10n.failedToLoad,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (complaints) {
              if (complaints.isEmpty) {
                return Text(
                  l10n.noComplaintsFound,
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final openCount = complaints
                  .where((c) => c['status'] == 'open')
                  .length;
              final resolvedCount = complaints
                  .where((c) => c['status'] == 'resolved')
                  .length;
              final escalatedCount = complaints
                  .where((c) => c['status'] == 'escalated')
                  .length;
              final urgentCount = complaints
                  .where((c) => c['priority'] == 'urgent')
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatCard(
                        title: l10n.total,
                        value: complaints.length.toString(),
                        icon: Icons.warning_amber_rounded,
                        color: Colors.amber,
                      ),
                      StatCard(
                        title: l10n.open,
                        value: openCount.toString(),
                        icon: Icons.radio_button_checked,
                        color: Colors.orange,
                      ),
                      StatCard(
                        title: l10n.resolvedStat,
                        value: resolvedCount.toString(),
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      StatCard(
                        title: l10n.escalated,
                        value: escalatedCount.toString(),
                        icon: Icons.trending_up_rounded,
                        color: Colors.red,
                      ),
                      StatCard(
                        title: l10n.urgent,
                        value: urgentCount.toString(),
                        icon: Icons.priority_high_rounded,
                        color: Colors.red.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.latestComplaints,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...complaints.take(5).map((c) {
                    final category = c['category'] as String? ?? '-';
                    final priority = c['priority'] as String? ?? '-';
                    final status = c['status'] as String? ?? '-';
                    final createdAt = c['created_at'] as String? ?? '';
                    final assignedAdmin =
                        c['assigned_admin_name'] as String?;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _complaintPriorityIcon(priority),
                        size: 16,
                        color: _complaintPriorityColor(priority),
                      ),
                      title: Text(
                        '$category â€” $status',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$priority Â· $createdAt${assignedAdmin != null ? ' Â· $assignedAdmin' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _complaintPriorityIcon(String priority) {
    return switch (priority) {
      'urgent' => Icons.priority_high_rounded,
      'high' => Icons.arrow_upward_rounded,
      'medium' => Icons.remove_rounded,
      _ => Icons.arrow_downward_rounded,
    };
  }

  Color _complaintPriorityColor(String priority) {
    return switch (priority) {
      'urgent' => Colors.red.shade700,
      'high' => Colors.orange,
      'medium' => Colors.amber,
      _ => Colors.green,
    };
  }
}

class _SupportSection extends ConsumerWidget {
  const _SupportSection({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final roomsAsync = ref.watch(memberSupportRoomsProvider(memberId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.chat_bubble_outline, size: 20),
        title: Text(l10n.supportSection),
        children: [
          roomsAsync.when(
            loading: () => const ShimmerLoading(
              child: SizedBox(height: 80),
            ),
            error: (e, _) => Text(
              l10n.failedToLoad,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (rooms) {
              if (rooms.isEmpty) {
                return Text(
                  l10n.noSupportConversations,
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final activeCount = rooms
                  .where((r) => r['status'] == 'active')
                  .length;
              final emergencyCount = rooms
                  .where((r) => r['is_emergency'] == true)
                  .length;
              final escalatedCount = rooms
                  .where((r) => r['escalation_status'] != null)
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatCard(
                        title: l10n.conversations,
                        value: rooms.length.toString(),
                        icon: Icons.chat_bubble_outline,
                        color: Colors.blue,
                      ),
                      StatCard(
                        title: l10n.activeStat,
                        value: activeCount.toString(),
                        icon: Icons.radio_button_checked,
                        color: Colors.green,
                      ),
                      StatCard(
                        title: l10n.emergencyStat,
                        value: emergencyCount.toString(),
                        icon: Icons.emergency_rounded,
                        color: Colors.red,
                      ),
                      StatCard(
                        title: l10n.escalated,
                        value: escalatedCount.toString(),
                        icon: Icons.trending_up_rounded,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...rooms.take(5).map((r) {
                    final roomTitle = r['title'] as String? ?? l10n.supportSection;
                    final priority = r['priority'] as String? ?? 'normal';
                    final isEmergency = r['is_emergency'] as bool? ?? false;
                    final assignedAdmin =
                        r['assigned_admin_name'] as String?;
                    final createdAt = r['created_at'] as String? ?? '';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isEmergency
                            ? Icons.emergency_rounded
                            : Icons.chat_bubble_outline,
                        size: 16,
                        color: isEmergency ? Colors.red : Colors.blue,
                      ),
                      title: Text(
                        roomTitle,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$priority Â· $createdAt${assignedAdmin != null ? ' Â· $assignedAdmin' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SanctionsSection extends ConsumerStatefulWidget {
  const _SanctionsSection({
    required this.memberId,
    required this.permissions,
  });

  final String memberId;
  final Map<String, dynamic> permissions;

  @override
  ConsumerState<_SanctionsSection> createState() => _SanctionsSectionState();
}

class _SanctionsSectionState extends ConsumerState<_SanctionsSection> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sanctionsAsync = ref.watch(memberSanctionsProvider(widget.memberId));
    final canIssueSanction =
        widget.permissions['can_issue_sanction'] as bool? ?? false;
    final canRevokeSanction =
        widget.permissions['can_revoke_sanction'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.gavel_rounded, size: 20),
        title: Text(l10n.sanctionsSection),
        children: [
          sanctionsAsync.when(
            loading: () => const ShimmerLoading(
              child: SizedBox(height: 100),
            ),
            error: (e, _) => Text(
              l10n.failedToLoad,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (sanctions) {
              if (sanctions.isEmpty) {
                return Text(
                  l10n.noSanctions,
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final active = sanctions
                  .where((s) => s['status'] == 'active')
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (active.isNotEmpty) ...[
                    Text(
                      l10n.activeSanctions,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...active.map((s) => _SanctionTile(
                          sanction: s,
                          canRevoke: canRevokeSanction,
                          onRevoked: () {
                            ref.invalidate(
                              memberSanctionsProvider(widget.memberId),
                            );
                          },
                        )),
                  ],
                  if (sanctions.length > active.length) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.history,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...sanctions
                        .where((s) => s['status'] != 'active')
                        .map((s) => _SanctionTile(
                              sanction: s,
                              canRevoke: false,
                              onRevoked: () {},
                            )),
                  ],
                  if (canIssueSanction) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () => _showIssueSanctionDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(l10n.issueSanction),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showIssueSanctionDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    String selectedType = 'warning';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.issueSanction),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: l10n.sanctionType,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'warning',
                    child: Text(l10n.warning),
                  ),
                  DropdownMenuItem(
                    value: 'fine',
                    child: Text(l10n.fine),
                  ),
                  DropdownMenuItem(
                    value: 'suspension',
                    child: Text(l10n.suspension),
                  ),
                  DropdownMenuItem(
                    value: 'temporary_ban',
                    child: Text(l10n.temporaryBan),
                  ),
                  DropdownMenuItem(
                    value: 'permanent_ban',
                    child: Text(l10n.permanentBan),
                  ),
                ],
                onChanged: (v) => setDialogState(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: l10n.reasonRequired,
                  hintText: l10n.enterSanctionReason,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                _issueSanction(selectedType, reasonController.text.trim());
              },
              child: Text(l10n.issue),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _issueSanction(String type, String reason) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isProcessing = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('issue_sanction', params: {
        'p_user_id': widget.memberId,
        'p_sanction_type': type,
        'p_reason': reason,
      });
      if (mounted) {
        ref.invalidate(memberSanctionsProvider(widget.memberId));
        ref.invalidate(memberOpsProfileProvider(widget.memberId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sanctionIssued)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedWithError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _SanctionTile extends ConsumerStatefulWidget {
  const _SanctionTile({
    required this.sanction,
    required this.canRevoke,
    required this.onRevoked,
  });

  final Map<String, dynamic> sanction;
  final bool canRevoke;
  final VoidCallback onRevoked;

  @override
  ConsumerState<_SanctionTile> createState() => _SanctionTileState();
}

class _SanctionTileState extends ConsumerState<_SanctionTile> {
  bool _isRevoking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = widget.sanction['sanction_type'] as String? ?? '?';
    final reason = widget.sanction['reason'] as String? ?? '';
    final issuedAt = widget.sanction['created_at'] as String? ?? '';
    final issuedBy = widget.sanction['issued_by_name'] as String?;
    final status = widget.sanction['status'] as String? ?? 'active';
    final expiry = widget.sanction['expires_at'] as String?;
    final sanctionId = widget.sanction['id'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.gavel_rounded,
            size: 16,
            color: status == 'active' ? Colors.orange : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$type â€” $status',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (reason.isNotEmpty)
                  Text(
                    reason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '$issuedAt${issuedBy != null ? ' Â· ${l10n.issuedBy(issuedBy)}' : ''}${expiry != null ? ' Â· ${l10n.expiresIn(expiry)}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (widget.canRevoke && status == 'active' && sanctionId.isNotEmpty)
            IconButton(
              icon: _isRevoking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.undo_rounded, size: 16),
              onPressed: _isRevoking ? null : () => _confirmRevoke(),
              tooltip: l10n.revoke,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRevoke() async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.revokeSanction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.revokeQuestion('${widget.sanction['sanction_type']}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: l10n.reason,
                hintText: l10n.enterRevocationReason,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.revoke),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isRevoking = true);
      try {
        final client = ref.read(supabaseClientProvider);
        await client.rpc('revoke_sanction', params: {
          'p_sanction_id': widget.sanction['id'],
          'p_reason': reasonController.text.isEmpty
              ? 'Revoked by admin'
              : reasonController.text,
        });
        if (mounted) {
          widget.onRevoked();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.sanctionRevoked)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.failedWithError(e.toString())),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isRevoking = false);
      }
    }
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final basic = profile['basic'] as Map<String, dynamic>? ?? {};
    final documents = <Map<String, dynamic>>[];

    final idCardUrl = basic['id_card_url'] as String?;
    if (idCardUrl != null && idCardUrl.isNotEmpty) {
      documents.add({
        'type': l10n.idCard,
        'url': idCardUrl,
        'status': l10n.submitted,
      });
    }

    final tradeLicenseUrl = basic['trade_license_url'] as String?;
    if (tradeLicenseUrl != null && tradeLicenseUrl.isNotEmpty) {
      documents.add({
        'type': l10n.tradeLicense,
        'url': tradeLicenseUrl,
        'status': l10n.submitted,
      });
    }

    final drivingLicenseUrl = basic['driving_license_url'] as String?;
    if (drivingLicenseUrl != null && drivingLicenseUrl.isNotEmpty) {
      documents.add({
        'type': l10n.drivingLicense,
        'url': drivingLicenseUrl,
        'status': l10n.submitted,
      });
    }

    final profilePhotoUrl = basic['avatar_url'] as String?;
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      documents.add({
        'type': l10n.profilePhoto,
        'url': profilePhotoUrl,
        'status': l10n.submitted,
      });
    }

    if (documents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.folder_outlined, size: 20),
        title: Text(l10n.documentsSection),
        children: documents.map((doc) {
          final type = doc['type'] as String;
          final status = doc['status'] as String;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, size: 16),
            title: Text(
              type,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              status,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AdminActionsSection extends ConsumerStatefulWidget {
  const _AdminActionsSection({
    required this.memberId,
    required this.profile,
    required this.permissions,
  });

  final String memberId;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> permissions;

  @override
  ConsumerState<_AdminActionsSection> createState() =>
      _AdminActionsSectionState();
}

class _AdminActionsSectionState extends ConsumerState<_AdminActionsSection> {

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentEmail = Supabase.instance.client.auth.currentUser?.email;
    final isOwner = currentEmail == AppConstants.ownerEmail;
    final canEditProfile = isOwner ||
        (widget.permissions['can_edit_profile'] as bool? ?? false);
    final canDecideVerification = isOwner ||
        (widget.permissions['can_decide_verification'] as bool? ?? false);
    final canIssueSanction = isOwner ||
        (widget.permissions['can_issue_sanction'] as bool? ?? false);
    final canRevokeSanction = isOwner ||
        (widget.permissions['can_revoke_sanction'] as bool? ?? false);
    final canRestrictAccount = isOwner ||
        (widget.permissions['can_restrict_account'] as bool? ?? false);
    final canSuspendAccount = isOwner ||
        (widget.permissions['can_suspend_account'] as bool? ?? false);
    final canDeleteAccount = isOwner ||
        (widget.permissions['can_delete_account'] as bool? ?? false);
    final cs = Theme.of(context).colorScheme;

    final basic = widget.profile['basic'] as Map<String, dynamic>? ?? {};
    final accountStatus = basic['account_status'] as String? ?? 'active';

    final hasAnyAction = canEditProfile ||
        canDecideVerification ||
        canIssueSanction ||
        canRevokeSanction ||
        canRestrictAccount ||
        canSuspendAccount ||
        canDeleteAccount;

    if (!hasAnyAction) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.admin_panel_settings_outlined, size: 20),
        title: Text(l10n.adminActionsSection),
        children: [
          if (canEditProfile)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined, size: 18),
              title: Text(l10n.editProfile, style: const TextStyle(fontSize: 13)),
              onTap: () {},
            ),
          if (canDecideVerification)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined, size: 18),
              title: Text(
                l10n.verificationDecision,
                style: const TextStyle(fontSize: 13),
              ),
              onTap: () {},
            ),
          if (canIssueSanction)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel_rounded, size: 18),
              title: Text(
                l10n.issueSanction,
                style: const TextStyle(fontSize: 13),
              ),
              onTap: () {},
            ),
          if (canRevokeSanction)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.undo_rounded, size: 18),
              title: Text(
                l10n.revokeSanction,
                style: const TextStyle(fontSize: 13),
              ),
              onTap: () {},
            ),
          if (canRestrictAccount && accountStatus == 'active')
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block_outlined, size: 18, color: Colors.orange),
              title: Text(
                l10n.restrictAccount,
                style: const TextStyle(fontSize: 13, color: Colors.orange),
              ),
              onTap: () => _showAccountActionDialog(
                l10n.restrict,
                'restrict_account',
                Colors.orange,
              ),
            ),
          if (canSuspendAccount &&
              (accountStatus == 'active' || accountStatus == 'restricted'))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pause_circle_outline, size: 18, color: Colors.red),
              title: Text(
                l10n.suspendAccount,
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
              onTap: () => _showAccountActionDialog(
                l10n.suspend,
                'suspend_account',
                Colors.red,
              ),
            ),
          if (canRestrictAccount && accountStatus == 'restricted')
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore_rounded, size: 18, color: Colors.green),
              title: Text(
                l10n.restoreAccount,
                style: const TextStyle(fontSize: 13, color: Colors.green),
              ),
              onTap: () => _showAccountActionDialog(
                l10n.restore,
                'restore_account',
                Colors.green,
              ),
            ),
          if (canSuspendAccount && accountStatus == 'suspended')
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore_rounded, size: 18, color: Colors.green),
              title: Text(
                l10n.restoreAccount,
                style: const TextStyle(fontSize: 13, color: Colors.green),
              ),
              onTap: () => _showAccountActionDialog(
                l10n.restore,
                'restore_account',
                Colors.green,
              ),
            ),
          if (canDeleteAccount)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_forever_outlined, size: 18, color: cs.error),
              title: Text(
                l10n.deleteAccount,
                style: TextStyle(fontSize: 13, color: cs.error),
              ),
              onTap: () => _showAccountActionDialog(
                l10n.delete,
                'delete_account',
                cs.error,
              ),
            ),
        ],
      ),
    );
  }

  void _showAccountActionDialog(
    String action,
    String actionKey,
    Color color,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (actionKey == 'delete_account') {
      await _confirmDeletion();
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(l10n.actionAccountTitle(action)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.actionConfirmMessage(action)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: l10n.reasonRequired,
                  hintText: l10n.enterReason,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text(action),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty || !mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);
      if (actionKey == 'restore_account') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.restorationUnsupported,
            ),
          ),
        );
        return;
      }
      final sanctionType = actionKey == 'suspend_account'
          ? 'suspension'
          : 'warning';
      await client.rpc('issue_sanction', params: {
        'p_member_id': widget.memberId,
        'p_sanction_type': sanctionType,
        'p_reason': reason.trim(),
      });
      if (mounted) {
        ref.invalidate(memberOpsProfileProvider(widget.memberId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountActionCompleted(action))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedWithError(e.toString()))),
        );
      }
    }
  }

  /// Deletion: Owner deletes directly. Others submit a deletion request
  /// that requires owner approval.
  Future<void> _confirmDeletion() async {
    final l10n = AppLocalizations.of(context);
    final basic = widget.profile['basic'] as Map<String, dynamic>? ?? {};
    final memberEmail = basic['email'] as String? ?? '';
    final currentEmail = Supabase.instance.client.auth.currentUser?.email;
    final isOwner = currentEmail == AppConstants.ownerEmail;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final reasonController = TextEditingController();
        return AlertDialog(
          title: Text(l10n.deleteAccount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isOwner
                    ? l10n.deleteAccountDirectMessage
                    : l10n.deleteAccountMessage),
                if (memberEmail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.memberEmailLabel(memberEmail),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: l10n.reasonRequired,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  maxLines: 3,
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () =>
                  Navigator.of(ctx).pop(reasonController.text.trim()),
              child: Text(isOwner ? l10n.deleteNow : l10n.submitDeletionRequest),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty || !mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);
      if (isOwner) {
        await client.from('users').update({
          'account_status': 'deactivated',
        }).eq('id', widget.memberId);
      } else {
        await client.rpc('request_member_deletion', params: {
          'p_member_id': widget.memberId,
          'p_confirmation_email': memberEmail,
          'p_reason': reason,
        });
      }
      if (mounted) {
        ref.invalidate(memberOpsProfileProvider(widget.memberId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOwner
                ? l10n.memberDeletedSuccessfully
                : l10n.deletionRequestSubmitted),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedWithError(e.toString()))),
        );
      }
    }
  }
}

/// Normalizes the live `get_member_ops_profile` (migration 049) response into
/// the map shape the member drawer expects.
///
/// The RPC returns top-level keys `member`, `region.label`, `location`,
/// `last_seen`, `driver`, `merchants`, `providers`, `orders`, `rides`,
/// `bookings`, `wallet`, `financials`, `active_sanctions`, `complaints`,
/// `support`, `timeline`, and `permissions` with `can_view_*`/`can_moderate`.
///
/// The drawer was originally written against `get_member_profile` (035) which
/// returned `basic`, `region.hierarchical_label` and fine-grained action
/// permissions. This adapter produces `basic` from `member` and maps the
/// permission vocabulary so the existing widgets render real data.
Map<String, dynamic> normalizeMemberOpsProfile(Map<String, dynamic> profile) {
  final member = profile['member'] as Map<String, dynamic>? ?? {};
  final region = profile['region'] as Map<String, dynamic>? ?? {};
  final permissions = profile['permissions'] as Map<String, dynamic>? ?? {};
  final lastSeen = profile['last_seen'] as String?;

  final canModerate = permissions['can_moderate'] as bool? ?? false;

  final basic = {
    ...member,
    'last_seen_at': lastSeen,
    'is_online': lastSeen != null &&
        DateTime.now().difference(DateTime.parse(lastSeen)).inMinutes < 5,
  };

  final adaptedRegion = {
    ...region,
    'hierarchical_label': region['label'] ?? '-',
  };

  return {
    ...profile,
    'basic': basic,
    'region': adaptedRegion,
    'permissions': {
      'can_view_location': permissions['can_view_location'] ?? false,
      'can_view_chat': permissions['can_view_chat'] ?? false,
      'can_view_documents': permissions['can_view_documents'] ?? false,
      'can_moderate': canModerate,
      'can_decide_verification': canModerate,
      'can_issue_sanction': canModerate,
      'can_revoke_sanction': canModerate,
      'can_restrict_account': canModerate,
      'can_suspend_account': canModerate,
      'can_delete_account': canModerate,
      'can_edit_profile': false,
    },
  };
}
