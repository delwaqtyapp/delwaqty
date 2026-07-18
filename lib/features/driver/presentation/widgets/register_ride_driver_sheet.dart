import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/presentation/widgets/ride_type_info.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class RegisterRideDriverSheet extends ConsumerStatefulWidget {
  const RegisterRideDriverSheet({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<RegisterRideDriverSheet> createState() =>
      _RegisterRideDriverSheetState();
}

class _RegisterRideDriverSheetState
    extends ConsumerState<RegisterRideDriverSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  RideType _category = RideType.economy;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authStateProvider);
    if (auth is AuthAuthenticated) {
      _name.text = auth.user.fullName ?? '';
      _phone.text = auth.user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _make.dispose();
    _model.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(dispatchRepositoryProvider).registerRideDriver(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            category: _category,
            make: _make.text.trim(),
            model: _model.text.trim(),
            color: _color.text.trim(),
            plate: _plate.text.trim(),
            seats: _category.passengerCapacity,
          );
      ref.invalidate(driverProfileProvider(widget.userId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorWithMessage(e.toString()))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.registerAsRideDriver,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _field(_name, l10n.fullName),
              _field(_phone, l10n.phoneNumber,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 8),
              DropdownButtonFormField<RideType>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: l10n.chooseRideType,
                  border: const OutlineInputBorder(),
                ),
                items: RideType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(RideTypeInfo.of(t, l10n).name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 8),
              _field(_make, l10n.vehicleMake),
              _field(_model, l10n.vehicleModel),
              _field(_color, l10n.vehicleColorLabel),
              _field(_plate, l10n.plateNumber),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.registerNow),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? label : null,
      ),
    );
  }
}
