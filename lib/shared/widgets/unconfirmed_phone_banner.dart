import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// True only when the signed-in user may confirm this customer's phone
/// (admin, the merchant that owns one of their orders, or their driver) AND
/// the customer signed up without a verified number. Any failure hides the
/// banner (the server still enforces every rule).
final customerPhoneNeedsConfirmationProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, customerId) async {
      if (customerId.isEmpty) return false;
      try {
        final r = await Supabase.instance.client.rpc(
          'customer_phone_needs_confirmation',
          params: {'p_user_id': customerId},
        );
        return r == true;
      } catch (_) {
        return false;
      }
    });

/// "Number not confirmed, call the customer" with a confirm button.
class UnconfirmedPhoneBanner extends ConsumerStatefulWidget {
  const UnconfirmedPhoneBanner({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<UnconfirmedPhoneBanner> createState() =>
      _UnconfirmedPhoneBannerState();
}

class _UnconfirmedPhoneBannerState
    extends ConsumerState<UnconfirmedPhoneBanner> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final r = await Supabase.instance.client.rpc(
        'confirm_customer_phone',
        params: {'p_user_id': widget.customerId},
      );
      if (r is! Map || r['ok'] != true) {
        throw StateError('confirm refused');
      }
      ref.invalidate(customerPhoneNeedsConfirmationProvider(widget.customerId));
      messenger.showSnackBar(SnackBar(content: Text(l10n.phoneConfirmedDone)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needs = ref
        .watch(customerPhoneNeedsConfirmationProvider(widget.customerId))
        .asData
        ?.value;
    if (needs != true) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight.withValues(alpha: 0.12),
        borderRadius: AppSpacing.borderRadiusMd,
        border: Border.all(
          color: AppColors.warningLight.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_in_talk_outlined, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.phoneNotConfirmedTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.phoneNotConfirmedBody, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: _busy ? null : _confirm,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(l10n.confirmPhoneAction),
            ),
          ),
        ],
      ),
    );
  }
}
