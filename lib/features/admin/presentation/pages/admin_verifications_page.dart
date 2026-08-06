import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:delwaqty/core/theme/app_colors.dart';

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
    final confirmed = await ConfirmDialog.show(
      context,
      title: l10n.adminVerifications,
      message: approve
          ? l10n.confirmApproveVerification
          : l10n.confirmRejectVerification,
      confirmLabel: approve ? l10n.approve : l10n.reject,
      isDestructive: !approve,
    );
    if (!confirmed || !mounted) return;

    setState(() => _processingUserId = request.userId);
    final adminService = ref.read(adminServiceProvider);
    final success = approve
        ? await adminService.approveVerification(request.userId)
        : await adminService.rejectVerification(request.userId);

    if (!mounted) return;
    setState(() => _processingUserId = null);
    if (success) {
      ref.invalidate(verificationRequestsProvider);
      context.showAppSnackBar(
        approve ? l10n.approvalSuccessful : l10n.rejectionSuccessful,
      );
    } else {
      context.showAppSnackBar(l10n.verificationDecisionFailed);
    }
  }

  void _showDocument({required String url, required String label}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final requestsAsync = ref.watch(verificationRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verificationRequests),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(verificationRequestsProvider),
          ),
        ],
      ),
      body: requestsAsync.when(
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
                      isProcessing: _processingUserId == requests[index].userId,
                      onApprove: () => _decide(requests[index], approve: true),
                      onReject: () => _decide(requests[index], approve: false),
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
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
                  isProvider ? l10n.userTypeProvider : l10n.userTypeDelivery,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (request.idCardUrl != null || request.profilePhotoUrl != null)
            Row(
              children: [
                if (request.idCardUrl != null)
                  Expanded(
                    child: _DocumentThumb(
                      label: l10n.idCard,
                      url: request.idCardUrl!,
                      onTap: () =>
                          onViewDocument(request.idCardUrl!, l10n.idCard),
                    ),
                  ),
                if (request.idCardUrl != null &&
                    request.profilePhotoUrl != null)
                  const SizedBox(width: 10),
                if (request.profilePhotoUrl != null)
                  Expanded(
                    child: _DocumentThumb(
                      label: l10n.profilePhoto,
                      url: request.profilePhotoUrl!,
                      onTap: () => onViewDocument(
                        request.profilePhotoUrl!,
                        l10n.profilePhoto,
                      ),
                    ),
                  ),
              ],
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
