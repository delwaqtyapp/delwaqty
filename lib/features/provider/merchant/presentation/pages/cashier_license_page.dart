import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Why `cashier_license_issue` refused. The server owns every rule (trial once
/// per shop, paid plans admin only, owner of the shop); the client only turns
/// the RPC's error code into a sentence.
enum CashierLicenseError {
  trialUsed,
  adminOnly,
  notAllowed,
  invalidDays,
  other,
}

CashierLicenseError cashierLicenseErrorOf(Object error) {
  final text = error is PostgrestException
      ? '${error.message} ${error.details ?? ''}'
      : error.toString();
  if (text.contains('TRIAL_ALREADY_USED')) return CashierLicenseError.trialUsed;
  if (text.contains('PAID_PLANS_REQUIRE_ADMIN')) {
    return CashierLicenseError.adminOnly;
  }
  if (text.contains('INVALID_DAYS')) return CashierLicenseError.invalidDays;
  if (text.contains('Not authorized')) return CashierLicenseError.notAllowed;
  return CashierLicenseError.other;
}

/// 12 digits grouped 4-4-4 for reading aloud; anything else is shown as is.
String formatCashierCode(String code) {
  final digits = code.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 12) return code;
  return '${digits.substring(0, 4)}-${digits.substring(4, 8)}-'
      '${digits.substring(8)}';
}

/// Plans an admin may issue (the server rejects anything else).
const cashierPaidPlans = <String>[
  'core_monthly',
  'core_quarterly',
  'core_semiannual',
  'core_annual',
  'core_lifetime',
];

final cashierLicensesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, merchantId) async {
      final data = await Supabase.instance.client
          .from('cashier_licenses')
          .select('id, short_code, plan, status, pro, expires_at, created_at')
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data as List);
    });

Future<Map<String, dynamic>> issueCashierLicense({
  required String merchantId,
  required String plan,
  int? days,
}) async {
  final res = await Supabase.instance.client.rpc(
    'cashier_license_issue',
    params: {
      'p_merchant_id': merchantId,
      'p_plan': plan,
      'p_days': days,
      'p_pro': null,
    },
  );
  return Map<String, dynamic>.from(res as Map);
}

/// Merchant route: resolves the signed-in owner's shop, then shows the page.
class MerchantCashierLicensePage extends ConsumerWidget {
  const MerchantCashierLicensePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(providerMerchantIdProvider);
    return id.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).cashierLicenseTitle),
        ),
        body: Center(
          child: Text(AppLocalizations.of(context).cashierLicenseIssueFailed),
        ),
      ),
      data: (merchantId) => CashierLicensePage(merchantId: merchantId),
    );
  }
}

/// Shows a shop's cashier licenses and issues new ones. The merchant owner can
/// start the one free trial; an admin ([adminMode]) can issue paid plans.
class CashierLicensePage extends ConsumerStatefulWidget {
  const CashierLicensePage({
    super.key,
    required this.merchantId,
    this.adminMode = false,
  });

  final String merchantId;
  final bool adminMode;

  @override
  ConsumerState<CashierLicensePage> createState() => _CashierLicensePageState();
}

class _CashierLicensePageState extends ConsumerState<CashierLicensePage> {
  bool _busy = false;

  String _errorText(AppLocalizations l10n, Object e) {
    return switch (cashierLicenseErrorOf(e)) {
      CashierLicenseError.trialUsed => l10n.cashierLicenseTrialUsed,
      CashierLicenseError.adminOnly => l10n.cashierLicenseAdminOnly,
      CashierLicenseError.notAllowed => l10n.cashierLicenseNotAllowed,
      CashierLicenseError.invalidDays => l10n.cashierLicenseInvalidDays,
      CashierLicenseError.other => l10n.cashierLicenseIssueFailed,
    };
  }

  String _planLabel(AppLocalizations l10n, String plan) => switch (plan) {
    'trial' => l10n.cashierLicensePlanTrial,
    'core_monthly' => l10n.cashierLicensePlanMonthly,
    'core_quarterly' => l10n.cashierLicensePlanQuarterly,
    'core_semiannual' => l10n.cashierLicensePlanSemiannual,
    'core_annual' => l10n.cashierLicensePlanAnnual,
    'core_lifetime' => l10n.cashierLicensePlanLifetime,
    _ => plan,
  };

  Future<void> _issue(String plan, {int? days}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final res = await issueCashierLicense(
        merchantId: widget.merchantId,
        plan: plan,
        days: days,
      );
      ref.invalidate(cashierLicensesProvider(widget.merchantId));
      if (!mounted) return;
      await _showKey(l10n, res['license_key'] as String? ?? '');
    } catch (e) {
      if (mounted) context.showAppSnackBar(_errorText(l10n, e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showKey(AppLocalizations l10n, String code) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cashierLicenseYourKey),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              formatCashierCode(code),
              style: Theme.of(ctx).textTheme.headlineSmall,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            Text(l10n.cashierLicenseKeyHint),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _copy(l10n, code),
            child: Text(l10n.cashierLicenseCopy),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(AppLocalizations l10n, String code) async {
    await Clipboard.setData(
      ClipboardData(text: code.replaceAll(RegExp(r'\D'), '')),
    );
    if (mounted) context.showAppSnackBar(l10n.cashierLicenseCopied);
  }

  Future<void> _askPaidPlan() async {
    final l10n = AppLocalizations.of(context);
    var plan = cashierPaidPlans.first;
    final daysController = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.cashierLicenseIssuePaid),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: plan,
                items: [
                  for (final p in cashierPaidPlans)
                    DropdownMenuItem(
                      value: p,
                      child: Text(_planLabel(l10n, p)),
                    ),
                ],
                onChanged: (v) => setLocal(() => plan = v ?? plan),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.cashierLicenseDaysOptional,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.cashierLicenseIssue),
            ),
          ],
        ),
      ),
    );
    final days = int.tryParse(daysController.text.trim());
    daysController.dispose();
    if (go == true && mounted) await _issue(plan, days: days);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final licenses = ref.watch(cashierLicensesProvider(widget.merchantId));
    final theme = Theme.of(context);
    final hasTrial = licenses.asData?.value.any((r) => r['plan'] == 'trial');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cashierLicenseTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.adminMode)
            FilledButton.icon(
              onPressed: _busy || hasTrial != false
                  ? null
                  : () => _issue('trial'),
              icon: const Icon(Icons.key_rounded),
              label: Text(l10n.cashierLicenseStartTrial),
            ),
          if (widget.adminMode)
            FilledButton.icon(
              onPressed: _busy ? null : _askPaidPlan,
              icon: const Icon(Icons.key_rounded),
              label: Text(l10n.cashierLicenseIssuePaid),
            ),
          const SizedBox(height: 16),
          licenses.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(l10n.cashierLicenseIssueFailed),
            data: (rows) {
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(l10n.cashierLicenseNone)),
                );
              }
              return Column(
                children: [
                  for (final r in rows)
                    Card(
                      child: ListTile(
                        title: Text(
                          formatCashierCode(r['short_code'] as String? ?? ''),
                          style: theme.textTheme.titleMedium,
                          textDirection: TextDirection.ltr,
                        ),
                        subtitle: Text(
                          '${_planLabel(l10n, r['plan'] as String? ?? '')}'
                          ' - ${r['status']}'
                          ' - ${_expiry(l10n, r['expires_at'] as String?)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_rounded),
                          tooltip: l10n.cashierLicenseCopy,
                          onPressed: () =>
                              _copy(l10n, r['short_code'] as String? ?? ''),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _expiry(AppLocalizations l10n, String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return l10n.cashierLicenseNeverExpires;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return l10n.cashierLicenseExpiresOn('${d.year}-$m-$day');
  }
}
