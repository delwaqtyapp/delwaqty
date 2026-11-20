import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/features/provider/financial/presentation/providers/financial_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class TopupRequestPage extends ConsumerStatefulWidget {
  const TopupRequestPage({super.key});

  @override
  ConsumerState<TopupRequestPage> createState() => _TopupRequestPageState();
}

class _TopupRequestPageState extends ConsumerState<TopupRequestPage> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _messageController = TextEditingController();
  String _method = 'bank_transfer';
  XFile? _proof;
  Uint8List? _proofBytes;
  bool _submitting = false;

  static const _methods = [
    'bank_transfer',
    'instapay',
    'vodafone_cash',
    'cash',
  ];

  String _methodLabel(AppLocalizations l10n, String method) {
    switch (method) {
      case 'bank_transfer':
        return l10n.paymentBankTransfer;
      case 'instapay':
        return l10n.paymentInstapay;
      case 'vodafone_cash':
        return l10n.paymentVodafoneCash;
      case 'cash':
        return l10n.paymentCash;
      default:
        return method;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _proof = picked;
      _proofBytes = bytes;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterValidAmount)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = ref.read(providerFinancialRepositoryProvider);
      String? proofPath;
      if (_proof != null && _proofBytes != null) {
        proofPath = await repo.uploadTopupProof(
          fileName: _proof!.name,
          bytes: _proofBytes!,
          contentType: _proof!.mimeType ?? 'image/jpeg',
        );
      }
      final result = await repo.createTopupRequest(
        amount: amount,
        paymentMethod: _method,
        transferReference: _referenceController.text.isEmpty
            ? null
            : _referenceController.text,
        proofPath: proofPath,
        message: _messageController.text.isEmpty
            ? null
            : _messageController.text,
      );
      if (!mounted) return;
      final ok = result['ok'] == true;
      final code = (result['code'] ?? (ok ? 'OK' : 'ERROR')).toString();
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.topUpRequestCreated(code))),
        );
        ref.invalidate(topupRequestsProvider);
        ref.invalidate(financialSummaryProvider);
        if (mounted) context.pop();
      } else {
        final errorDetail = result['message']?.toString().trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.topUpFailed(
                errorDetail != null && errorDetail.isNotEmpty
                    ? errorDetail
                    : code,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appErrorText(context, e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildReceivingAccountCard(AppLocalizations l10n) {
    final receiverAsync = ref.watch(receiverProvider);
    return receiverAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final accountNumber =
            (data['wallet_number'] ?? data['account_number'] ?? '')
                .toString()
                .trim();
        final accountName =
            (data['account_name'] ?? data['display_name'] ?? '')
                .toString()
                .trim();
        final providerLabel = (data['provider'] ?? '').toString().trim();
        final instructions = (data['instructions'] ?? '').toString().trim();
        if (accountNumber.isEmpty && accountName.isEmpty) {
          return const SizedBox.shrink();
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.receivingAccountTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (accountName.isNotEmpty) Text(accountName),
                if (providerLabel.isNotEmpty)
                  Text(
                    providerLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (accountNumber.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          accountNumber,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.copyAccountNumber,
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: accountNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.copyAccountNumber)),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    instructions,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestTopUp)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReceivingAccountCard(l10n),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.amount,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            items: _methods
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(_methodLabel(l10n, m)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _method = v ?? _method),
            decoration: InputDecoration(
              labelText: l10n.paymentMethod,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referenceController,
            decoration: InputDecoration(
              labelText: l10n.transferReference,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.messageOptional,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: Text(l10n.proofOfPayment),
              subtitle: _proof == null
                  ? Text(l10n.tapToAddProof)
                  : Text(_proof!.name),
              trailing: _proof == null
                  ? const Icon(Icons.add_a_photo_rounded)
                  : TextButton(
                      onPressed: _pickProof,
                      child: Text(l10n.changeProof),
                    ),
              onTap: _proof == null ? _pickProof : null,
            ),
          ),
          if (_proofBytes != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_proofBytes!, height: 180, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.submitRequest),
          ),
        ],
      ),
    );
  }
}
