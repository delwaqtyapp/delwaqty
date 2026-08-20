import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

final _providersProvider =
    FutureProvider.family<List<dynamic>, ServiceCategoryType>((ref, type) async {
  final repo = ref.watch(serviceBookingRepositoryProvider);
  return repo.getProviders(categoryType: type);
});

class ServiceBookingPage extends ConsumerStatefulWidget {
  const ServiceBookingPage({super.key, required this.categoryType});

  final ServiceCategoryType categoryType;

  @override
  ConsumerState<ServiceBookingPage> createState() => _ServiceBookingPageState();
}

class _ServiceBookingPageState extends ConsumerState<ServiceBookingPage> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedProviderId;
  String? _selectedProviderName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _categoryName(AppLocalizations l10n) => switch (widget.categoryType) {
    ServiceCategoryType.plumbing => 'Ø³Ø¨Ø§ÙƒØ©',
    ServiceCategoryType.electrical => 'ÙƒÙ‡Ø±Ø¨Ø§Ø¡',
    ServiceCategoryType.carpentry => 'Ù†Ø¬Ø§Ø±Ø©',
    ServiceCategoryType.acMaintenance => 'ØµÙŠØ§Ù†Ø© ØªÙƒÙŠÙŠÙ',
    ServiceCategoryType.painting => 'Ø¯Ù‡Ø§Ù†',
    ServiceCategoryType.cleaning => 'ØªÙ†Ø¸ÙŠÙ',
    ServiceCategoryType.pestControl => 'Ù…ÙƒØ§ÙØ­Ø© Ø­Ø´Ø±Ø§Øª',
    ServiceCategoryType.applianceRepair => 'Ø¥ØµÙ„Ø§Ø­ Ø£Ø¬Ù‡Ø²Ø©',
    ServiceCategoryType.other => 'Ø®Ø¯Ù…Ø§Øª Ø£Ø®Ø±Ù‰',
  };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submitBooking() async {
    if (_selectedProviderId == null || _selectedProviderName == null) return;

    final authState = ref.read(authStateProvider);
    if (authState is! AuthAuthenticated) {
      context.push('/login');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(serviceBookingRepositoryProvider);
      await repo.createBooking(
        userId: authState.user.id,
        providerId: _selectedProviderId!,
        providerName: _selectedProviderName!,
        categoryType: widget.categoryType,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        scheduledDate: _selectedDate,
        scheduledTime:
            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        address: '',
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ØªÙ… Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø­Ø¬Ø² Ø¨Ù†Ø¬Ø§Ø­'),
            backgroundColor: AppColors.successLight,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ø­Ø¯Ø« Ø®Ø·Ø£. Ø­Ø§ÙˆÙ„ Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final providersAsync = ref.watch(_providersProvider(widget.categoryType));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _categoryName(l10n),
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedFadeIn(
              child: Text(
                'Ø§Ø®ØªØ± Ù…Ø²ÙˆØ¯ Ø§Ù„Ø®Ø¯Ù…Ø©',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            providersAsync.when(
              loading: () => const ShimmerCard(height: 100),
              error: (_, __) => const PremiumEmptyState(
                icon: Icons.error_outline,
                title: 'Ø®Ø·Ø£',
                message: 'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ù…Ø²ÙˆØ¯ÙŠ Ø§Ù„Ø®Ø¯Ù…Ø©',
              ),
              data: (providers) {
                if (providers.isEmpty) {
                  return const PremiumEmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'Ù„Ø§ ÙŠÙˆØ¬Ø¯ Ù…Ø²ÙˆØ¯ÙŠÙ†',
                    message: 'Ù„Ù… ÙŠØªÙ… Ø§Ù„Ø¹Ø«ÙˆØ± Ø¹Ù„Ù‰ Ù…Ø²ÙˆØ¯ÙŠ Ø®Ø¯Ù…Ø© Ù…ØªØ§Ø­ÙŠÙ†',
                  );
                }
                return SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: providers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final provider = providers[index];
                      final isSelected = _selectedProviderId == provider.id;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedProviderId = provider.id;
                          _selectedProviderName = provider.name;
                        }),
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandPurple.withValues(alpha: 0.12)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandPurple
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    AppColors.brandPurple.withValues(alpha: 0.12),
                                child: Text(
                                  provider.name.substring(0, 1),
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: AppColors.brandPurple,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.name,
                                style: AppTextStyles.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (provider.rating > 0) ...[
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 12, color: AppColors.rating),
                                    const SizedBox(width: 2),
                                    Text(
                                      provider.rating.toStringAsFixed(1),
                                      style: AppTextStyles.labelSmall.copyWith(
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 100),
              child: Text(
                'ØªØ§Ø±ÙŠØ® ÙˆÙˆÙ‚Øª Ø§Ù„Ø­Ø¬Ø²',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 150),
              child: Row(
                children: [
                  Expanded(
                    child: _DateTimeButton(
                      icon: Icons.calendar_today_rounded,
                      label: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateTimeButton(
                      icon: Icons.access_time_rounded,
                      label: _selectedTime.format(context),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'ÙˆØµÙ Ø§Ù„Ù…Ø´ÙƒÙ„Ø©',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 250),
              child: TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ø§Ø´Ø±Ø­ Ø§Ù„Ù…Ø´ÙƒÙ„Ø© Ø¨Ø§Ù„ØªÙØµÙŠÙ„...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 300),
              child: TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Ù…Ù„Ø§Ø­Ø¸Ø§Øª Ø¥Ø¶Ø§ÙÙŠØ© (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 350),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _selectedProviderId == null || _isSubmitting
                      ? null
                      : _submitBooking,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø­Ø¬Ø²',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.brandPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
