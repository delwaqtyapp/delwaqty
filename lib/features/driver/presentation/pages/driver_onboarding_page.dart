import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/driver/domain/repositories/driver_repository.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class DriverOnboardingPage extends ConsumerStatefulWidget {
  const DriverOnboardingPage({super.key, required this.driverId});

  final String driverId;

  @override
  ConsumerState<DriverOnboardingPage> createState() =>
      _DriverOnboardingPageState();
}

class _DriverOnboardingPageState extends ConsumerState<DriverOnboardingPage> {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _seatsController = TextEditingController(text: '4');

  int _currentStep = 0;
  bool _isSubmitting = false;

  static const _totalSteps = 6;

  static const _vehicleCategories = [
    'economy',
    'comfort',
    'premium',
    'xl',
    'motorbike',
    'taxi',
    'motorcycle',
    'scooter',
    'van',
    'pickup',
  ];

  String _selectedCategory = 'economy';

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nationalIdController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  DriverRepository get _repo => ref.read(driverRepositoryProvider);

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitCurrentStep() async {
    if (_isSubmitting) return;

    if (_currentStep == 0 && !_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      switch (_currentStep) {
        case 0:
          await _repo.submitOnboardingStep(
            widget.driverId,
            step: 0,
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            nationalId: _nationalIdController.text.trim(),
          );
        case 1:
          await _repo.submitOnboardingStep(widget.driverId, step: 1);
        case 2:
          await _repo.submitOnboardingStep(widget.driverId, step: 2);
        case 3:
          await _repo.submitOnboardingStep(widget.driverId, step: 3);
        case 4:
          await _repo.submitOnboardingStep(widget.driverId, step: 4);
        case 5:
          await _repo.addVehicle(
            widget.driverId,
            category: _selectedCategory,
            make: _makeController.text.trim().isNotEmpty
                ? _makeController.text.trim()
                : null,
            model: _modelController.text.trim().isNotEmpty
                ? _modelController.text.trim()
                : null,
            year: int.tryParse(_yearController.text.trim()),
            color: _colorController.text.trim().isNotEmpty
                ? _colorController.text.trim()
                : null,
            plateNumber: _plateController.text.trim(),
            seats: int.tryParse(_seatsController.text.trim()) ?? 4,
          );
          await _repo.submitOnboardingStep(widget.driverId, step: 5);
          await _repo.completeOnboarding(widget.driverId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).registrationSubmitted,
                ),
              ),
            );
            context.go('/driver');
          }
          return;
      }

      if (mounted) {
        _nextStep();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showUploadPlaceholder(String documentType) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.uploadComingSoon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingTitle),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: Column(
        children: [
          _buildStepIndicator(theme, l10n),
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPersonalInfoStep(l10n),
                  _buildProfilePhotoStep(l10n),
                  _buildDocumentStep(
                    l10n: l10n,
                    title: l10n.drivingLicense,
                    uploadLabel: l10n.uploadDrivingLicense,
                    documentType: 'driving_license',
                    icon: Icons.badge_outlined,
                  ),
                  _buildDocumentStep(
                    l10n: l10n,
                    title: l10n.vehicleRegistration,
                    uploadLabel: l10n.uploadVehicleRegistration,
                    documentType: 'vehicle_registration',
                    icon: Icons.description_outlined,
                  ),
                  _buildDocumentStep(
                    l10n: l10n,
                    title: l10n.insurance,
                    uploadLabel: l10n.uploadInsurance,
                    documentType: 'insurance',
                    icon: Icons.shield_outlined,
                  ),
                  _buildVehicleInfoStep(l10n),
                ],
              ),
            ),
          ),
          _buildBottomBar(theme, l10n),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme, AppLocalizations l10n) {
    final progress = (_currentStep + 1) / _totalSteps;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.stepOf(_currentStep + 1, _totalSteps),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AnimatedFadeIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.personalInfo,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: l10n.fullName,
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: l10n.phoneNumber,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: l10n.address,
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nationalIdController,
              decoration: InputDecoration(
                labelText: l10n.nationalId,
                prefixIcon: const Icon(Icons.credit_card_outlined),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.requiredField;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhotoStep(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AnimatedFadeIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profilePhoto,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () => _showUploadPlaceholder('profile_photo'),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(80),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.uploadPhoto,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentStep({
    required AppLocalizations l10n,
    required String title,
    required String uploadLabel,
    required String documentType,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AnimatedFadeIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _showUploadPlaceholder(documentType),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      uploadLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.tapToUpload,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleInfoStep(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AnimatedFadeIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.vehicleInfo,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: l10n.vehicleCategory,
                prefixIcon: const Icon(Icons.category_outlined),
                border: const OutlineInputBorder(),
              ),
              items: _vehicleCategories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _makeController,
              decoration: InputDecoration(
                labelText: l10n.vehicleMake,
                prefixIcon: const Icon(Icons.directions_car_outlined),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: l10n.vehicleModel,
                prefixIcon: const Icon(Icons.directions_car_outlined),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _yearController,
              decoration: InputDecoration(
                labelText: l10n.vehicleYear,
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _colorController,
              decoration: InputDecoration(
                labelText: l10n.vehicleColor,
                prefixIcon: const Icon(Icons.palette_outlined),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _plateController,
              decoration: InputDecoration(
                labelText: l10n.plateNumber,
                prefixIcon: const Icon(Icons.pin_outlined),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _seatsController,
              decoration: InputDecoration(
                labelText: l10n.seats,
                prefixIcon: const Icon(Icons.people_outline),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.requiredField;
                }
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed < 1) {
                  return l10n.requiredField;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, AppLocalizations l10n) {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submitCurrentStep,
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    isLastStep ? l10n.submitRegistration : l10n.next,
                  ),
          ),
        ),
      ),
    );
  }
}
