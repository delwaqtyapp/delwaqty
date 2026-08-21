import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/provider/financial/presentation/providers/financial_providers.dart';

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
  bool _submitting = false;

  static const _methods = [
    'bank_transfer',
    'instapay',
    'vodafone_cash',
    'cash',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = ref.read(providerFinancialRepositoryProvider);
      final result = await repo.createTopupRequest(
        amount: amount,
        paymentMethod: _method,
        transferReference: _referenceController.text.isEmpty
            ? null
            : _referenceController.text,
        message: _messageController.text.isEmpty
            ? null
            : _messageController.text,
      );
      if (!mounted) return;
      final ok = result['ok'] == true;
      final code = result['code'] ?? (ok ? 'OK' : 'ERROR');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Top-up request: $code')),
      );
      if (ok) {
        ref.invalidate(topupRequestsProvider);
        if (mounted) context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Request top-up')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              items: _methods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v ?? _method),
              decoration: const InputDecoration(
                labelText: 'Payment method',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Transfer reference (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const CircularProgressIndicator()
                  : const Text('Submit request'),
            ),
          ],
        ),
      );
}
