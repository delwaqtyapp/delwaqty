import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// تسجيل سيارة السائق كمنتج في متجر السيارات.
/// السعر يحدده السائق نفسه (وليس جوجل) وتأخذ المنصة عمولة 7% عند الحجز.
class CarSellerFormPage extends ConsumerStatefulWidget {
  const CarSellerFormPage({super.key});

  @override
  ConsumerState<CarSellerFormPage> createState() => _CarSellerFormPageState();
}

class _CarSellerFormPageState extends ConsumerState<CarSellerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _seatsController = TextEditingController(text: '4');
  final _cityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'car';
  bool _submitting = false;

  static const _categories = <(String, String, String)>[
    ('car', 'سيارة', 'Car'),
    ('van', 'فان', 'Van'),
    ('pickup', 'بيك أب', 'Pickup'),
    ('microbus', 'ميكروباص', 'Microbus'),
    ('tuk_tuk', 'توك توك', 'Tuk tuk'),
  ];

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _seatsController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginRequired)),
      );
      return;
    }
    final userId = auth.user.id;
    setState(() => _submitting = true);
    try {
      await ref.read(serviceBookingRepositoryProvider).createCarProduct(
            sellerId: userId,
            category: _category,
            make: _makeController.text.trim(),
            model: _modelController.text.trim(),
            year: int.tryParse(_yearController.text.trim()),
            color: _colorController.text.trim().isEmpty
                ? null
                : _colorController.text.trim(),
            seats: int.tryParse(_seatsController.text.trim()) ?? 4,
            city: _cityController.text.trim(),
            price: double.parse(_priceController.text.trim()),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.carProductCreated)),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.errorLoading}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeIsAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sellCarTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.sellCarHint,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.brandSoftGray,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.carCategoryLabel, style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    label: Text(localeIsAr ? c.$2 : c.$3),
                    selected: _category == c.$1,
                    onSelected: (_) => setState(() => _category = c.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.carMakeLabel, style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _makeController,
              decoration: InputDecoration(
                hintText: l10n.carMakeHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
            ),
            const SizedBox(height: 14),
            Text(l10n.carModelLabel, style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _modelController,
              decoration: InputDecoration(
                hintText: l10n.carModelHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.carYearLabel,
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '2020',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.carSeatsLabel,
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _seatsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '4',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(l10n.carColorLabel, style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _colorController,
              decoration: InputDecoration(
                hintText: l10n.carColorHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Text(l10n.carCityLabel, style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: l10n.carCityHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
            ),
            const SizedBox(height: 14),
            Text(l10n.carPriceLabel, style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: l10n.carPriceHint,
                suffixText: 'EGP',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final price = double.tryParse(v ?? '');
                if (price == null || price <= 0) return l10n.requiredField;
                return null;
              },
            ),
            const SizedBox(height: 14),
            Text(l10n.carDescriptionLabel, style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.carDescriptionHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.sellCarSubmit),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}