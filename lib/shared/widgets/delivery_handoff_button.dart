import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/utils/rpc_result.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Only the server can decide who may see a handoff challenge. Drivers never
/// receive it in a ride row or in their acceptance response.
class DeliveryHandoffButton extends StatefulWidget {
  const DeliveryHandoffButton({
    super.key,
    this.rideId,
    this.orderId,
    required this.pickup,
  });
  final String? rideId;
  final String? orderId;
  final bool pickup;
  @override
  State<DeliveryHandoffButton> createState() => _DeliveryHandoffButtonState();
}

class _DeliveryHandoffButtonState extends State<DeliveryHandoffButton> {
  bool _loading = false;
  Future<void> _show() async {
    setState(() => _loading = true);
    try {
      final result = checkedRpcResult(
        await Supabase.instance.client.rpc(
          'delivery_handoff_code',
          params: {
            'p_stage': widget.pickup ? 'pickup' : 'dropoff',
            'p_ride_id': widget.rideId,
            'p_order_id': widget.orderId,
          },
        ),
        onFailure: Exception.new,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => DeliveryHandoffDialog(
          pickup: widget.pickup,
          code: result['code'] as String,
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(appErrorText(context, error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      onPressed: _loading ? null : _show,
      icon: const Icon(Icons.lock_outline),
      label: Text(
        widget.pickup ? l10n.pickupHandoffCode : l10n.recipientHandoffCode,
      ),
    );
  }
}

class DeliveryHandoffDialog extends StatelessWidget {
  const DeliveryHandoffDialog({
    super.key,
    required this.pickup,
    required this.code,
  });
  final bool pickup;
  final String code;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(pickup ? l10n.pickupHandoffCode : l10n.recipientHandoffCode),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            code,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(letterSpacing: 5),
          ),
          const SizedBox(height: 16),
          Text(pickup ? l10n.pickupHandoffHint : l10n.recipientHandoffHint),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class DeliveryHandoffInputDialog extends StatefulWidget {
  const DeliveryHandoffInputDialog({super.key, required this.pickup});
  final bool pickup;
  @override
  State<DeliveryHandoffInputDialog> createState() =>
      _DeliveryHandoffInputDialogState();
}

class _DeliveryHandoffInputDialogState
    extends State<DeliveryHandoffInputDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.pickup ? l10n.pickupHandoffCode : l10n.recipientHandoffCode,
      ),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        maxLength: 6,
        autocorrect: false,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          helperText: widget.pickup
              ? l10n.askPickupHandoff
              : l10n.askRecipientHandoff,
          helperMaxLines: 4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _controller.text.length == 6
              ? () => Navigator.pop(context, _controller.text)
              : null,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
