import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/car_product.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class CarTripOrderPage extends ConsumerStatefulWidget {
  const CarTripOrderPage({
    super.key,
    required this.carProductId,
  });

  final String carProductId;

  @override
  ConsumerState<CarTripOrderPage> createState() => _CarTripOrderPageState();
}

class _CarTripOrderPageState extends ConsumerState<CarTripOrderPage> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime? _scheduledDateTime;
  bool isLoading = false;
  bool _submitting = false;
  String? errorMessage;
  CarProduct? _carProduct;

  @override
  void initState() {
    super.initState();
    _loadCarProduct();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCarProduct() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final carProduct = await ref
          .read(serviceBookingRepositoryProvider)
          .getCarProduct(widget.carProductId);
      if (!mounted) return;
      setState(() {
        _carProduct = carProduct;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatScheduled(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }

  Future<void> _submitOrder() async {
    final l10n = AppLocalizations.of(context);
    if (_pickupController.text.trim().isEmpty ||
        _dropoffController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fillRequiredFields)),
      );
      return;
    }
    setState(() {
      _submitting = true;
      errorMessage = null;
    });
    try {
      await ref
          .read(serviceBookingRepositoryProvider)
          .submitCarTripOrder(
            carProductId: widget.carProductId,
            pickupAddress: _pickupController.text.trim(),
            dropoffAddress: _dropoffController.text.trim(),
            phone: _phoneController.text.trim(),
            scheduledAt: _scheduledDateTime,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.carTripOrdered)),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorLoading}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chooseCar)),
      body: isLoading && _carProduct == null
          ? const Center(child: ShimmerCard(height: 220))
          : _carProduct == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.errorLoading,
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadCarProduct,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCarCard(l10n),
                      const SizedBox(height: 20),
                      Text(l10n.pickupAddress,
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pickupController,
                        decoration: InputDecoration(
                          hintText: l10n.enterPickupHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(l10n.dropoffAddress,
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dropoffController,
                        decoration: InputDecoration(
                          hintText: l10n.enterDropoffHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(l10n.phone, style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: l10n.enterPhoneHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(l10n.note, style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: l10n.enterNoteHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Scheduled time (pre-booking)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.schedule),
                          title: Text(l10n.scheduledTime),
                          subtitle: Text(
                            _scheduledDateTime == null
                                ? l10n.chooseDateTime
                                : _formatScheduled(_scheduledDateTime!),
                          ),
                          trailing: TextButton(
                            onPressed: _pickDateTime,
                            child: Text(_scheduledDateTime == null
                                ? l10n.chooseDateTime
                                : l10n.editScheduleTime),
                          ),
                        ),
                      ),
                      // Map / place
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.map),
                          title: Text(l10n.placeAndMap),
                          subtitle: Text(l10n.openInMapsHint),
                          trailing: _carProduct!.latitude != null &&
                                  _carProduct!.longitude != null
                              ? TextButton.icon(
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: Text(l10n.openInMaps),
                                  onPressed: () async {
                                    final lat = _carProduct!.latitude;
                                    final lng = _carProduct!.longitude;
                                    final url = 'geo:$lat,$lng?q=$lat,$lng';
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                )
                              : null,
                        ),
                      ),
                      // Price breakdown (commission precise)
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _priceRow(
                                l10n.driverPrice,
                                '${_carProduct!.price.toStringAsFixed(2)} EGP',
                                bold: false,
                              ),
                              const Divider(height: 20),
                              _priceRow(
                                l10n.ourCommission,
                                '+ ${(_carProduct!.price * 7 / 100).toStringAsFixed(2)} EGP',
                                bold: false,
                                hint: '7%',
                              ),
                              const SizedBox(height: 8),
                              _priceRow(
                                l10n.totalPaid,
                                '${(_carProduct!.price + (_carProduct!.price * 7 / 100)).toStringAsFixed(2)} EGP',
                                bold: true,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.commissionBreakdown,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.brandSoftGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submitOrder,
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l10n.bookTrip),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCarCard(AppLocalizations l10n) {
    final car = _carProduct!;
    Widget photo;
    if (car.photoUrl != null && car.photoUrl!.isNotEmpty) {
      photo = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          car.photoUrl!,
          width: 88,
          height: 66,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 88,
            height: 66,
            color: AppColors.surfaceContainerHighestLight,
            child: const Icon(Icons.directions_car, size: 36),
          ),
        ),
      );
    } else {
      photo = Container(
        width: 88,
        height: 66,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighestLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.directions_car, size: 36),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            photo,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${car.make ?? ''} ${car.model ?? ''}'
                    '${car.year != null ? ' ${car.year}' : ''}',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_categoryLabel(l10n, car.category)} • ${car.seats} '
                    '${l10n.seatsLabel}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.brandSoftGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          car.city,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  String _categoryLabel(AppLocalizations l10n, String category) {
    return switch (category) {
      'van' => l10n.carCategoryVan,
      'pickup' => l10n.carCategoryPickup,
      'microbus' => l10n.carCategoryMicrobus,
      'tuk_tuk' => l10n.carCategoryTukTuk,
      _ => l10n.carCategoryCar,
    };
  }

  Widget _priceRow(
    String label,
    String amount, {
    required bool bold,
    String? hint,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          hint != null ? '$label ($hint)' : label,
          style: bold
              ? AppTextStyles.titleMedium
              : AppTextStyles.bodyMedium,
        ),
        Text(
          amount,
          style: bold
              ? AppTextStyles.titleLarge.copyWith(
                  color: AppColors.brandPurple,
                  fontWeight: FontWeight.bold,
                )
              : AppTextStyles.titleMedium,
        ),
      ],
    );
  }
}