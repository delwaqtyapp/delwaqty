import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/domain/entities/vehicle.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _vehiclesProvider = FutureProvider.family<List<Vehicle>, String>((ref, driverId) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getVehicles(driverId);
});

const _vehicleCategories = [
  'economy',
  'comfort',
  'premium',
  'taxi',
  'xl',
  'van',
  'pickup',
  'motorbike',
  'motorcycle',
  'scooter',
];

IconData _categoryIcon(String category) {
  switch (category) {
    case 'economy':
    case 'comfort':
    case 'premium':
    case 'taxi':
      return Icons.directions_car_rounded;
    case 'xl':
    case 'van':
    case 'pickup':
      return Icons.local_shipping_rounded;
    case 'motorbike':
    case 'motorcycle':
    case 'scooter':
      return Icons.two_wheeler_rounded;
    default:
      return Icons.directions_car_rounded;
  }
}

class VehicleManagementPage extends ConsumerWidget {
  const VehicleManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);

    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vehicleManagement)),
        body: Center(child: Text(l10n.pleaseLogIn)),
      );
    }

    final profileAsync = ref.watch(driverProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleManagement)),
      body: profileAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerCard(),
            SizedBox(height: 12),
            ShimmerCard(),
          ],
        ),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l10n.noVehicles));
          }
          return _VehicleListBody(driverId: profile.id);
        },
      ),
      floatingActionButton: profileAsync.hasValue && profileAsync.value != null
          ? FloatingActionButton(
              onPressed: () => _showAddVehicleSheet(
                context,
                ref,
                profileAsync.value!.id,
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _showAddVehicleSheet(BuildContext context, WidgetRef ref, String driverId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VehicleFormSheet(driverId: driverId),
    );
  }
}

class _VehicleListBody extends ConsumerWidget {
  const _VehicleListBody({required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehiclesAsync = ref.watch(_vehiclesProvider(driverId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_vehiclesProvider(driverId)),
      child: vehiclesAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerCard(),
            SizedBox(height: 12),
            ShimmerCard(),
          ],
        ),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage(e.toString()))),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noVehicles,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return AnimatedFadeIn(
                delay: Duration(milliseconds: 80 * index),
                child: _VehicleCard(
                  vehicle: vehicle,
                  onToggleActive: () async {
                    final repo = ref.read(driverRepositoryProvider);
                    await repo.toggleVehicleActive(vehicle.id, driverId);
                    ref.invalidate(_vehiclesProvider(driverId));
                  },
                  onEdit: () => _showEditVehicleSheet(context, ref, vehicle),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditVehicleSheet(BuildContext context, WidgetRef ref, Vehicle vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VehicleFormSheet(
        driverId: vehicle.driverId,
        vehicle: vehicle,
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onToggleActive,
    required this.onEdit,
  });

  final Vehicle vehicle;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = [
      vehicle.make,
      vehicle.model,
    ].where((e) => e != null && e.isNotEmpty).join(' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _categoryIcon(vehicle.category),
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isNotEmpty ? title : l10n.notSet,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (vehicle.isVerified)
                        Icon(
                          Icons.verified_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (vehicle.year != null) '${vehicle.year}',
                      if (vehicle.color != null && vehicle.color!.isNotEmpty) vehicle.color!,
                      vehicle.plateNumber,
                      if (vehicle.seats > 0) '${vehicle.seats} ${l10n.seats}',
                    ].join(' \u2022 '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch(
                        value: vehicle.isActive,
                        onChanged: (_) => onToggleActive(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.isActive ? l10n.vehicleActive : l10n.vehicleInactive,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: vehicle.isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 20),
                      ),
                    ],
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

class _VehicleFormSheet extends ConsumerStatefulWidget {
  const _VehicleFormSheet({
    required this.driverId,
    this.vehicle,
  });

  final String driverId;
  final Vehicle? vehicle;

  @override
  ConsumerState<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends ConsumerState<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _category;
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _seatsController = TextEditingController(text: '4');
  bool _isSaving = false;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _category = v?.category ?? 'economy';
    if (v != null) {
      _makeController.text = v.make ?? '';
      _modelController.text = v.model ?? '';
      if (v.year != null) _yearController.text = v.year.toString();
      _colorController.text = v.color ?? '';
      _plateController.text = v.plateNumber;
      _seatsController.text = v.seats.toString();
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isEditing ? l10n.editVehicle : l10n.addVehicle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: l10n.vehicleCategory,
                  border: const OutlineInputBorder(),
                ),
                items: _vehicleCategories.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c[0].toUpperCase() + c.substring(1)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _makeController,
                decoration: InputDecoration(
                  labelText: l10n.vehicleMake,
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: l10n.vehicleModel,
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      decoration: InputDecoration(
                        labelText: l10n.vehicleYear,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _seatsController,
                      decoration: InputDecoration(
                        labelText: l10n.seats,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                decoration: InputDecoration(
                  labelText: l10n.vehicleColorLabel,
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                decoration: InputDecoration(
                  labelText: l10n.vehiclePlateLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.fieldRequired;
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(driverRepositoryProvider);

      if (_isEditing) {
        await repo.updateVehicle(
          widget.vehicle!.id,
          widget.driverId,
          category: _category,
          make: _makeController.text.trim().isNotEmpty ? _makeController.text.trim() : null,
          model: _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : null,
          year: int.tryParse(_yearController.text.trim()),
          color: _colorController.text.trim().isNotEmpty ? _colorController.text.trim() : null,
          plateNumber: _plateController.text.trim(),
          seats: int.tryParse(_seatsController.text.trim()) ?? 4,
        );
      } else {
        await repo.addVehicle(
          widget.driverId,
          category: _category,
          make: _makeController.text.trim().isNotEmpty ? _makeController.text.trim() : null,
          model: _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : null,
          year: int.tryParse(_yearController.text.trim()),
          color: _colorController.text.trim().isNotEmpty ? _colorController.text.trim() : null,
          plateNumber: _plateController.text.trim(),
          seats: int.tryParse(_seatsController.text.trim()) ?? 4,
        );
      }

      ref.invalidate(_vehiclesProvider(widget.driverId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
