import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminApprovalsCenterPage extends ConsumerStatefulWidget {
  const AdminApprovalsCenterPage({super.key});

  @override
  ConsumerState<AdminApprovalsCenterPage> createState() =>
      _AdminApprovalsCenterPageState();
}

class _AdminApprovalsCenterPageState
    extends ConsumerState<AdminApprovalsCenterPage> {
  String? _processingId;

  String _typeLabel(AppLocalizations l10n, String type) {
    return switch (type) {
      'admin_create' => l10n.reqTypeAdminCreate,
      'admin_role_change' => l10n.reqTypeAdminRole,
      'admin_region_change' => l10n.reqTypeAdminRegion,
      'admin_supervisor_change' => l10n.reqTypeAdminSupervisor,
      'admin_deactivate' => l10n.reqTypeAdminDeactivate,
      'campaign_approve' => l10n.reqTypeCampaign,
      'member_ban' => l10n.reqTypeMemberBan,
      'member_delete' => l10n.reqTypeMemberDelete,
      'offer_approve' => l10n.reqTypeOfferApprove,
      'offer_publish' => l10n.reqTypeOfferPublish,
      'reward_config_change' => l10n.reqTypeRewardConfig,
      _ => type,
    };
  }

  Future<void> _decide(
    Map<String, dynamic> request, {
    required bool approve,
  }) async {
    final l10n = AppLocalizations.of(context);
    final requestId = request['id'] as String;
    String? reason;

    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text(l10n.rejectRequest),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: '${l10n.reason} *',
                hintText: l10n.rejectionReasonHint,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) return;
                  Navigator.of(ctx).pop(controller.text.trim());
                },
                child: Text(l10n.confirm),
              ),
            ],
          );
        },
      );
      if (reason == null || !mounted) return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.approvalRequest,
      message: approve
          ? l10n.approvalConfirmApprove
          : '$l10n.approvalConfirmReject — $reason',
      confirmLabel: approve ? l10n.approveRequest : l10n.rejectRequest,
      isDestructive: !approve,
    );
    if (!confirmed || !mounted) return;

    setState(() => _processingId = requestId);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('decide_approval_request', params: {
        'p_request_id': requestId,
        'p_decision': approve ? 'approve' : 'reject',
        'p_reason': approve ? null : reason,
      });
      if (mounted) {
        ref.invalidate(pendingApprovalsProvider);
        context.showAppSnackBar(
          approve
              ? l10n.approvalRequestApproved
              : l10n.approvalRequestRejected,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar('${l10n.approvalDecisionFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final approvalsAsync = ref.watch(pendingApprovalsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminApprovalsCenter),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pendingApprovalsProvider),
          ),
        ],
      ),
      body: approvalsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => Center(
          child: PremiumEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: l10n.errorLoading,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(pendingApprovalsProvider),
          ),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.fact_check_outlined,
                title: l10n.adminApprovals,
                message: l10n.noPendingApprovals,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final isProcessing = _processingId == request['id'];
              return AnimatedFadeIn(
                delay: Duration(milliseconds: index * 40),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _typeLabel(l10n, request['request_type'] as String),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(request['created_at'] as String?),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.requester}: ${request['requested_by']}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (request['reason'] != null &&
                            (request['reason'] as String).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.reason}: ${request['reason']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    isProcessing || request['state'] != 'pending'
                                        ? null
                                        : () => _decide(request, approve: false),
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: Text(l10n.rejectRequest),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    isProcessing || request['state'] != 'pending'
                                        ? null
                                        : () => _decide(request, approve: true),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: isProcessing
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(l10n.approveRequest),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}