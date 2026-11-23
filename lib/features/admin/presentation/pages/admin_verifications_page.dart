import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

final multiServiceRequestsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    final res = await Supabase.instance.client.rpc(
      'list_provider_profile_requests',
      params: {'p_status': 'pending'},
    );
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  },
);

class AdminVerificationsPage extends ConsumerStatefulWidget {
  const AdminVerificationsPage({super.key});

  @override
  ConsumerState<AdminVerificationsPage> createState() =>
      _AdminVerificationsPageState();
}

class _AdminVerificationsPageState
    extends ConsumerState<AdminVerificationsPage> {
  String? _processingUserId;

  Future<void> _decide(
    VerificationRequest request, {
    required bool approve,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (!approve) {
      final reason = await _askRejectReason(l10n);
      if (reason == null || !mounted) return;
      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.adminVerifications,
        message: l10n.confirmRejectVerification,
        confirmLabel: l10n.reject,
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;

      setState(() => _processingUserId = request.userId);
      final success = await ref
          .read(adminServiceProvider)
          .rejectVerification(request.userId, reason: reason);
      if (!mounted) return;
      setState(() => _processingUserId = null);
      if (success) {
        ref.invalidate(verificationRequestsProvider);
        context.showAppSnackBar(l10n.rejectionSuccessful);
      } else {
        context.showAppSnackBar(l10n.verificationDecisionFailed);
      }
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.adminVerifications,
      message: l10n.confirmApproveVerification,
      confirmLabel: l10n.approve,
    );
    if (!confirmed || !mounted) return;

    setState(() => _processingUserId = request.userId);
    final success = await ref
        .read(adminServiceProvider)
        .approveVerification(request.userId);
    if (!mounted) return;
    setState(() => _processingUserId = null);
    if (success) {
      ref.invalidate(verificationRequestsProvider);
      context.showAppSnackBar(l10n.approvalSuccessful);
    } else {
      context.showAppSnackBar(l10n.verificationDecisionFailed);
    }
  }

  Future<String?> _askRejectReason(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.verificationRejectReasonTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.verificationRejectReasonHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.reject),
          ),
        ],
      ),
    );
    return (reason == null || reason.isEmpty) ? null : reason;
  }

  void _showDocument({required String url, required String label}) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: IconButton(
                tooltip: l10n.close,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 240,
                      height: 320,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stack) => Container(
                    width: 240,
                    height: 320,
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decideMultiService(
    Map<String, dynamic> req, {
    required bool approve,
  }) async {
    final l10n = AppLocalizations.of(context);
    String? reason;
    if (!approve) {
      reason = await _askRejectReason(l10n);
      if (reason == null || !mounted) return;
    } else {
      final confirmed = await ConfirmDialog.show(
        context,
        title: l10n.adminVerifications,
        message: l10n.confirmApproveVerification,
        confirmLabel: l10n.approve,
      );
      if (!confirmed || !mounted) return;
    }
    final id = req['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _processingUserId = id);
    try {
      await Supabase.instance.client.rpc(
        'decide_provider_profile_request',
        params: {
          'p_profile_id': id,
          'p_decision': approve ? 'approved' : 'rejected',
          'p_reason': ?reason,
        },
      );
      ref.invalidate(multiServiceRequestsProvider);
      if (mounted) {
        context.showAppSnackBar(
          approve ? l10n.approvalSuccessful : l10n.rejectionSuccessful,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _processingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final requestsAsync = ref.watch(verificationRequestsProvider);
    final multiAsync = ref.watch(multiServiceRequestsProvider);
    final multiCount = multiAsync.value?.length ?? 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: MediaQuery.sizeOf(context).width < 1100
              ? const AdminMenuButton()
              : null,
          title: Text(l10n.verificationRequests),
          actions: [
            IconButton(
              tooltip: l10n.refresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(verificationRequestsProvider);
                ref.invalidate(multiServiceRequestsProvider);
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.verificationRequests),
              Tab(
                text: multiCount > 0
                    ? '${l10n.multiServiceRequestsTitle} ($multiCount)'
                    : l10n.multiServiceRequestsTitle,
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            requestsAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(verificationRequestsProvider),
                ),
              ),
              data: (requests) {
                if (requests.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.verified_user_outlined,
                    title: l10n.verificationRequests,
                    message: l10n.noVerificationRequests,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(verificationRequestsProvider);
                    await ref.read(verificationRequestsProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: 100 + index * 60),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: index < requests.length - 1 ? 12 : 0,
                          ),
                          child: _VerificationCard(
                            request: requests[index],
                            cs: cs,
                            isProcessing:
                                _processingUserId == requests[index].userId,
                            onApprove: () =>
                                _decide(requests[index], approve: true),
                            onReject: () =>
                                _decide(requests[index], approve: false),
                            onViewDocument: (url, label) =>
                                _showDocument(url: url, label: label),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            multiAsync.when(
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: appErrorText(context, e),
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(multiServiceRequestsProvider),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.add_business_rounded,
                    title: l10n.multiServiceRequestsTitle,
                    message: l10n.noMultiServiceRequests,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(multiServiceRequestsProvider);
                    await ref.read(multiServiceRequestsProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final req = list[index];
                      final id = req['id']?.toString() ?? '';
                      final busy = _processingUserId == id;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.add_business_rounded,
                                    color: AppColors.brandPurple,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (req['display_name'] ?? '').toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      (req['category_type'] ?? '').toString(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${req['user_name'] ?? ''} · ${req['user_phone'] ?? req['user_email'] ?? ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => _decideMultiService(
                                            req,
                                            approve: false,
                                          ),
                                    child: Text(l10n.reject),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => _decideMultiService(
                                            req,
                                            approve: true,
                                          ),
                                    child: Text(l10n.approve),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.request,
    required this.cs,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
    required this.onViewDocument,
  });

  final VerificationRequest request;
  final ColorScheme cs;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final void Function(String url, String label) onViewDocument;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isProvider = request.userType == UserType.provider;
    final typeColor = isProvider
        ? const Color(0xFF34C759)
        : const Color(0xFFFF9500);
    final typeIcon = isProvider
        ? Icons.handyman_outlined
        : Icons.local_shipping_outlined;

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.fullName ?? request.email,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.email,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _verificationTypeLabel(l10n, request.userType.code),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (request.phone != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  request.phone!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${l10n.joinedDate}: ${MaterialLocalizations.of(context).formatMediumDate(request.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _VerificationDocsSection(
            userId: request.userId,
            onViewDocument: onViewDocument,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(l10n.reject),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isProcessing
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brandPurple,
                            ),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: onApprove,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF34C759),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(l10n.approve),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loads and lays out every document the applicant uploaded at
/// registration (ID card, driving license, trade license, profile photo),
/// each openable for review. When nothing was uploaded the admin sees an
/// explicit note instead of a blank card - approving with no documents is
/// a visible choice, not an accident.
class _VerificationDocsSection extends ConsumerWidget {
  const _VerificationDocsSection({
    required this.userId,
    required this.onViewDocument,
  });

  final String userId;
  final void Function(String url, String label) onViewDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final docsAsync = ref.watch(verificationDocumentsProvider(userId));
    final cs = Theme.of(context).colorScheme;

    return docsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (docs) {
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.error.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.noDocuments,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cs.error),
                  ),
                ),
              ],
            ),
          );
        }
        final entries = <MapEntry<String, String>>[
          if (docs.idCardUrl != null) MapEntry(l10n.idCard, docs.idCardUrl!),
          if (docs.drivingLicenseUrl != null)
            MapEntry(l10n.drivingLicense, docs.drivingLicenseUrl!),
          if (docs.tradeLicenseUrl != null)
            MapEntry(l10n.tradeLicense, docs.tradeLicenseUrl!),
          if (docs.profilePhotoUrl != null)
            MapEntry(l10n.profilePhoto, docs.profilePhotoUrl!),
        ];
        final rows = <Widget>[];
        for (var i = 0; i < entries.length; i += 2) {
          rows.add(
            Row(
              children: [
                Expanded(
                  child: _DocumentThumb(
                    label: entries[i].key,
                    url: entries[i].value,
                    onTap: () =>
                        onViewDocument(entries[i].value, entries[i].key),
                  ),
                ),
                if (i + 1 < entries.length) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DocumentThumb(
                      label: entries[i + 1].key,
                      url: entries[i + 1].value,
                      onTap: () => onViewDocument(
                        entries[i + 1].value,
                        entries[i + 1].key,
                      ),
                    ),
                  ),
                ] else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          );
          if (i + 2 < entries.length) rows.add(const SizedBox(height: 10));
        }
        return Column(children: rows);
      },
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  const _DocumentThumb({
    required this.label,
    required this.url,
    required this.onTap,
  });

  final String label;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                url,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stack) => SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Row(
                children: [
                  const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _verificationTypeLabel(AppLocalizations l10n, String code) {
  switch (code) {
    case 'driver':
      return l10n.driver;
    case 'merchant':
      return l10n.merchant;
    case 'customer':
      return l10n.customer;
    case 'provider':
      return l10n.provider;
    default:
      return code;
  }
}
