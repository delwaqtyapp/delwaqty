import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/router/post_auth_route.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/home/presentation/widgets/category_visuals.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/cinematic_auth_background.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/pressable_scale.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';

const _kRegBg = Color(0xFF0A0614);
const _kGold = Color(0xFFD4AF37);

/// The live catalog of the app's REAL booking services (same data source the
/// customer Home / All-Services screens read). The provider registration
/// picker renders from here so the account always lists every service the app
/// actually offers, linked to the real `ServiceCategoryType` ids.
final providerServicesCatalogProvider = FutureProvider<List<ServiceCategory>>(
  (ref) {
    final repo = ref.watch(cachedServiceBookingRepositoryProvider);
    return repo.getCategories();
  },
);

const _servicePriority = [
  ServiceCategoryType.doctor,
  ServiceCategoryType.nurse,
  ServiceCategoryType.teacher,
  ServiceCategoryType.barber,
  ServiceCategoryType.plumbing,
  ServiceCategoryType.electrical,
  ServiceCategoryType.carpentry,
  ServiceCategoryType.painting,
  ServiceCategoryType.cleaning,
  ServiceCategoryType.acMaintenance,
  ServiceCategoryType.pipeChange,
  ServiceCategoryType.plastering,
  ServiceCategoryType.carpetCleaning,
  ServiceCategoryType.dishRepair,
  ServiceCategoryType.pestControl,
  ServiceCategoryType.applianceRepair,
];

int _serviceRank(ServiceCategoryType type) {
  final i = _servicePriority.indexOf(type);
  return i == -1 ? _servicePriority.length : i;
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _currentStep = 0;
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  String _selectedLanguage = 'ar';

  UserType? _selectedRole;
  XFile? _idCardFile;
  XFile? _profilePhotoFile;
  XFile? _tradeLicenseFile;
  XFile? _drivingLicenseFile;
  final Set<String> _selectedServices = {};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      final role = _selectedRole;
      if (role == null) {
        context.showAppSnackBar(AppLocalizations.of(context).selectAccountType);
        return;
      }
      if (role.requiresVerification &&
          (_idCardFile == null || _profilePhotoFile == null)) {
        context.showAppSnackBar(AppLocalizations.of(context).documentsRequired);
        return;
      }
      if (role.requiresTradeLicense && _tradeLicenseFile == null) {
        context.showAppSnackBar(AppLocalizations.of(context).documentsRequired);
        return;
      }
      if (role.requiresDrivingLicense && _drivingLicenseFile == null) {
        context.showAppSnackBar(AppLocalizations.of(context).documentsRequired);
        return;
      }
      setState(() => _currentStep++);
      return;
    }
    if (_currentStep == 1) {
      if (!_formKey.currentState!.validate()) return;
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickDocument({required String documentType}) async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF181122),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1035).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.photo_library_outlined,
                      label: l10n.gallery,
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.photo_camera_outlined,
                      label: l10n.camera,
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    setState(() {
      switch (documentType) {
        case 'idCard':
          _idCardFile = file;
          break;
        case 'profilePhoto':
          _profilePhotoFile = file;
          break;
        case 'tradeLicense':
          _tradeLicenseFile = file;
          break;
        case 'drivingLicense':
          _drivingLicenseFile = file;
          break;
      }
    });
  }

  Future<void> _onRegister() async {
    final role = _selectedRole!;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(StorageKeys.deliveryUpdates, _notificationsEnabled);
      await prefs.setBool(StorageKeys.locationEnabled, _locationEnabled);
      await prefs.setString(StorageKeys.customerLocale, _selectedLanguage);
      if (role == UserType.provider) {
        await prefs.setString(
          StorageKeys.providerServices,
          _selectedServices.join(','),
        );
      }
    } catch (_) {}
    Uint8List? idCardBytes;
    String? idCardFileName;
    Uint8List? profilePhotoBytes;
    String? profilePhotoFileName;
    Uint8List? tradeLicenseBytes;
    String? tradeLicenseFileName;
    Uint8List? drivingLicenseBytes;
    String? drivingLicenseFileName;

    if (_idCardFile != null) {
      idCardBytes = await _idCardFile!.readAsBytes();
      idCardFileName = _idCardFile!.name;
    }
    if (_profilePhotoFile != null) {
      profilePhotoBytes = await _profilePhotoFile!.readAsBytes();
      profilePhotoFileName = _profilePhotoFile!.name;
    }
    if (_tradeLicenseFile != null) {
      tradeLicenseBytes = await _tradeLicenseFile!.readAsBytes();
      tradeLicenseFileName = _tradeLicenseFile!.name;
    }
    if (_drivingLicenseFile != null) {
      drivingLicenseBytes = await _drivingLicenseFile!.readAsBytes();
      drivingLicenseFileName = _drivingLicenseFile!.name;
    }

    await ref
        .read(authStateProvider.notifier)
        .signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          userType: role,
          language: _selectedLanguage,
          idCardBytes: idCardBytes,
          idCardFileName: idCardFileName,
          profilePhotoBytes: profilePhotoBytes,
          profilePhotoFileName: profilePhotoFileName,
          tradeLicenseBytes: tradeLicenseBytes,
          tradeLicenseFileName: tradeLicenseFileName,
          drivingLicenseBytes: drivingLicenseBytes,
          drivingLicenseFileName: drivingLicenseFileName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);

    ref.listen<AuthState>(authStateProvider, (prev, next) {
      next.whenOrNull(
        authenticated: (_) =>
            context.go(postAuthRoute(ref.read(appFlavorProvider))),
        pendingVerification: () => context.go('/pending-verification'),
        emailConfirmationRequired: (email) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(l10n.emailConfirmationTitle),
              content: Text(l10n.emailConfirmationSent(email)),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/login');
                  },
                  child: Text(l10n.ok),
                ),
              ],
            ),
          );
        },
        error: (msg) => context.showAppSnackBar(msg),
      );
    });

    return Scaffold(
      backgroundColor: _kRegBg,
      body: Stack(
        children: [
          const CinematicAuthBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(l10n),
                _buildStepper(l10n),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(
                        key: ValueKey('register_step_$_currentStep'),
                        child: _buildStepContent(l10n, authState),
                      ),
                    ),
                  ),
                ),
                _buildBottomActions(l10n, authState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          PressableScale(
            scale: 0.92,
            onTap: _currentStep > 0 ? _prevStep : () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                _currentStep > 0
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.75),
                size: 17,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandPurple, AppColors.brandCyan],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPurple.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.register,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.createAccount,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(AppLocalizations l10n) {
    const icons = [
      Icons.account_circle_outlined,
      Icons.person_outline_rounded,
      Icons.tune_rounded,
      Icons.reviews_outlined,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(
        children: [
          for (var i = 0; i < icons.length; i++) ...[
            _StepDot(
              icon: icons[i],
              isActive: i <= _currentStep,
              isCurrent: i == _currentStep,
            ),
            if (i < icons.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: i < _currentStep
                        ? const LinearGradient(
                            colors: [AppColors.brandPurple, AppColors.brandCyan],
                          )
                        : null,
                    color: i < _currentStep
                        ? null
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
          ],
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kGold.withValues(alpha: 0.35)),
            ),
            child: Text(
              l10n.stepOf(_currentStep + 1, 4),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kGold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(AppLocalizations l10n, AuthState authState) {
    return switch (_currentStep) {
      0 => _buildStepRole(l10n),
      1 => _buildStepInfo(l10n),
      2 => _buildStepPreferences(l10n),
      3 => _buildStepConfirmation(l10n, authState),
      _ => const SizedBox(),
    };
  }

  Widget _buildStepRole(AppLocalizations l10n) {
    final roles = [
      (
        UserType.customer,
        Icons.person_outline_rounded,
        l10n.userTypeCustomer,
        l10n.userTypeCustomerDesc,
        const Color(0xFF4A90D9),
      ),
      (
        UserType.merchant,
        Icons.store_outlined,
        l10n.userTypeMerchant,
        l10n.userTypeMerchantDesc,
        const Color(0xFF8B5CF6),
      ),
      (
        UserType.driver,
        Icons.delivery_dining_outlined,
        l10n.userTypeDriver,
        l10n.userTypeDriverDesc,
        const Color(0xFFFF9500),
      ),
      (
        UserType.provider,
        Icons.handyman_outlined,
        l10n.userTypeProvider,
        l10n.userTypeProviderDesc,
        const Color(0xFF34C759),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _StepHeading(
          eyebrow: l10n.stepOf(1, 4),
          title: l10n.selectAccountType,
          subtitle: l10n.accountTypeDescription,
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < roles.length; i += 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedFadeIn(
                  delay: Duration(milliseconds: 100 + i * 70),
                  child: _RolePremiumCard(
                    icon: roles[i].$2,
                    title: roles[i].$3,
                    subtitle: roles[i].$4,
                    color: roles[i].$5,
                    isSelected: _selectedRole == roles[i].$1,
                    onTap: () => setState(() => _selectedRole = roles[i].$1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (i + 1 < roles.length)
                Expanded(
                  child: AnimatedFadeIn(
                    delay: Duration(milliseconds: 170 + i * 70),
                    child: _RolePremiumCard(
                      icon: roles[i + 1].$2,
                      title: roles[i + 1].$3,
                      subtitle: roles[i + 1].$4,
                      color: roles[i + 1].$5,
                      isSelected: _selectedRole == roles[i + 1].$1,
                      onTap: () =>
                          setState(() => _selectedRole = roles[i + 1].$1),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (_selectedRole != null && _selectedRole!.requiresVerification) ...[
          const SizedBox(height: 6),
          _PremiumUploadTile(
            icon: Icons.badge_outlined,
            title: l10n.uploadIdCard,
            hint: l10n.uploadIdCardHint,
            color: const Color(0xFF007AFF),
            hasFile: _idCardFile != null,
            onTap: () => _pickDocument(documentType: 'idCard'),
          ),
          const SizedBox(height: 12),
          _PremiumUploadTile(
            icon: Icons.person_outline_rounded,
            title: l10n.uploadProfilePhoto,
            hint: l10n.uploadProfilePhotoHint,
            color: const Color(0xFFAF52DE),
            hasFile: _profilePhotoFile != null,
            onTap: () => _pickDocument(documentType: 'profilePhoto'),
          ),
          if (_selectedRole!.requiresTradeLicense) ...[
            const SizedBox(height: 12),
            _PremiumUploadTile(
              icon: Icons.description_outlined,
              title: l10n.uploadTradeLicense,
              hint: l10n.uploadTradeLicenseHint,
              color: const Color(0xFF34C759),
              hasFile: _tradeLicenseFile != null,
              onTap: () => _pickDocument(documentType: 'tradeLicense'),
            ),
          ],
          if (_selectedRole!.requiresDrivingLicense) ...[
            const SizedBox(height: 12),
            _PremiumUploadTile(
              icon: Icons.local_shipping_outlined,
              title: l10n.uploadDrivingLicense,
              hint: l10n.uploadDrivingLicenseHint,
              color: const Color(0xFFFF9500),
              hasFile: _drivingLicenseFile != null,
              onTap: () => _pickDocument(documentType: 'drivingLicense'),
            ),
          ],
        ],
        if (_selectedRole == UserType.provider) ...[
          const SizedBox(height: 8),
          _ProviderServicesPicker(
            selected: _selectedServices,
            onToggle: (type) => setState(() {
              if (!_selectedServices.add(type)) _selectedServices.remove(type);
            }),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStepInfo(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _StepHeading(
            eyebrow: l10n.stepOf(2, 4),
            title: l10n.createAccount,
            subtitle: l10n.fillDetailsToStart,
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final nameField = _PremiumField(
                controller: _nameController,
                hint: l10n.fullName,
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) => AppValidators.required(v),
              );
              final phoneField = _PremiumField(
                controller: _phoneController,
                hint: l10n.phoneNumber,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              );
              if (constraints.maxWidth >= 340) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: nameField),
                    const SizedBox(width: 12),
                    Expanded(child: phoneField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  nameField,
                  const SizedBox(height: 14),
                  phoneField,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _PremiumField(
            controller: _emailController,
            hint: l10n.email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) => AppValidators.email(v),
          ),
          const SizedBox(height: 14),
          _PremiumField(
            controller: _passwordController,
            hint: l10n.password,
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            validator: (v) => AppValidators.password(v),
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.white.withValues(alpha: 0.55),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PremiumField(
            controller: _confirmPasswordController,
            hint: l10n.confirmPassword,
            icon: Icons.lock_outline_rounded,
            obscure: _obscureConfirm,
            validator: (v) =>
                AppValidators.confirmPassword(v, _passwordController.text),
            suffix: GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.white.withValues(alpha: 0.55),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStepPreferences(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _StepHeading(
          eyebrow: l10n.stepOf(3, 4),
          title: l10n.preferencesTitle,
          subtitle: l10n.customizeExperience,
        ),
        const SizedBox(height: 24),
        _GlassCard(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              Expanded(
                child: _LanguageOption(
                  label: 'العربية',
                  isSelected: _selectedLanguage == 'ar',
                  onTap: () => setState(() => _selectedLanguage = 'ar'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _LanguageOption(
                  label: 'English',
                  isSelected: _selectedLanguage == 'en',
                  onTap: () => setState(() => _selectedLanguage = 'en'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PrefToggleCard(
          icon: Icons.notifications_outlined,
          title: l10n.notifications,
          subtitle: l10n.receiveUpdatesOffers,
          value: _notificationsEnabled,
          onChanged: (v) => setState(() => _notificationsEnabled = v),
        ),
        const SizedBox(height: 12),
        _PrefToggleCard(
          icon: Icons.location_on_outlined,
          title: l10n.location,
          subtitle: l10n.findNearbyServices,
          value: _locationEnabled,
          onChanged: (v) => setState(() => _locationEnabled = v),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStepConfirmation(AppLocalizations l10n, AuthState authState) {
    final roleLabels = {
      UserType.customer: l10n.userTypeCustomer,
      UserType.merchant: l10n.userTypeMerchant,
      UserType.driver: l10n.userTypeDriver,
      UserType.provider: l10n.userTypeProvider,
    };
    final documents = [
      if (_idCardFile != null) l10n.uploadIdCard,
      if (_profilePhotoFile != null) l10n.uploadProfilePhoto,
      if (_tradeLicenseFile != null) l10n.uploadTradeLicense,
      if (_drivingLicenseFile != null) l10n.uploadDrivingLicense,
    ];

    final services = ref
        .watch(providerServicesCatalogProvider)
        .asData
        ?.value
        .where((s) => _selectedServices.contains(s.type.name))
        .toList();
    final localeIsAr = Directionality.of(context) == TextDirection.rtl;
    final serviceNames = <String>[
      if (services != null)
        for (final s in services)
          if (localeIsAr) s.nameAr else s.nameEn,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        AnimatedFadeIn(
          duration: const Duration(milliseconds: 500),
          child: _StepHeading(
            eyebrow: l10n.stepOf(4, 4),
            title: l10n.reviewAndConfirm,
            subtitle: l10n.reviewSummaryHint,
          ),
        ),
        const SizedBox(height: 24),
        _GlassCard(
          isSelected: true,
          child: Row(
            children: [
              const _IconWell(
                icon: Icons.workspace_premium_rounded,
                color: _kGold,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.accountTypeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      roleLabels[_selectedRole] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ReviewTile(
          icon: Icons.person_outline_rounded,
          label: l10n.fullName,
          value: _nameController.text.trim(),
        ),
        _ReviewTile(
          icon: Icons.email_outlined,
          label: l10n.email,
          value: _emailController.text.trim(),
        ),
        if (_phoneController.text.trim().isNotEmpty)
          _ReviewTile(
            icon: Icons.phone_outlined,
            label: l10n.phoneNumber,
            value: _phoneController.text.trim(),
          ),
        _ReviewTile(
          icon: Icons.description_outlined,
          label: l10n.documentsAttached,
          value: documents.isEmpty
              ? l10n.noDocumentsRequired
              : documents.join('، '),
        ),
        if (serviceNames.isNotEmpty)
          _ReviewTile(
            icon: Icons.handyman_outlined,
            label: l10n.providerServices,
            value: serviceNames.join('، '),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBottomActions(AppLocalizations l10n, AuthState authState) {
    final isLoading = authState is AuthLoading;
    final isLastStep = _currentStep == 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        children: [
          if (_currentStep > 0) ...[
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isLoading ? null : _prevStep,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.55),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                child: Text(
                  l10n.back,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
          ],
          PressableScale(
            scale: 0.98,
            onTap: isLoading
                ? () {}
                : isLastStep
                ? _onRegister
                : _nextStep,
            child: Container(
              key: isLastStep
                  ? const Key('registerSubmit')
                  : const Key('registerStepNext'),
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandPurple, AppColors.brandCyan],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPurple.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLastStep ? l10n.register : l10n.next,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kGold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kGold.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: _kGold,
                size: 12,
              ),
              const SizedBox(width: 5),
              Text(
                eyebrow,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.icon,
    required this.isActive,
    required this.isCurrent,
  });

  final IconData icon;
  final bool isActive;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isActive
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandPurple, AppColors.brandCyan],
              )
            : null,
        color: isActive ? null : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.brandPurple.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
        size: 15,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.isSelected = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isSelected ? 0.13 : 0.07),
            Colors.white.withValues(alpha: isSelected ? 0.05 : 0.03),
          ],
        ),
        border: Border.all(
          color: isSelected
              ? _kGold.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.12),
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.38 : 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          if (isSelected)
            BoxShadow(
              color: _kGold.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: child,
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _RolePremiumCard extends StatelessWidget {
  const _RolePremiumCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipStart =
        isSelected ? Color.lerp(_kGold, color, 0.4)! : color.withValues(alpha: 0.18);
    final chipEnd =
        isSelected ? Color.lerp(_kGold, color, 0.7)! : color.withValues(alpha: 0.07);
    return PressableScale(
      scale: 0.97,
      onTap: onTap,
      child: Stack(
        children: [
          _GlassCard(
            isSelected: isSelected,
            padding: const EdgeInsets.all(14),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [chipStart, chipEnd],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: 10,
              right: 10,
              child: AnimatedScale(
                scale: 1,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _kGold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kGold.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF0A0614),
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumUploadTile extends StatelessWidget {
  const _PremiumUploadTile({
    required this.icon,
    required this.title,
    required this.hint,
    required this.color,
    required this.hasFile,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final Color color;
  final bool hasFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scale: 0.98,
      onTap: onTap,
      child: _GlassCard(
        isSelected: hasFile,
        padding: const EdgeInsets.all(12),
        radius: 20,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                hasFile
                    ? Icons.check_circle_rounded
                    : Icons.cloud_upload_outlined,
                key: ValueKey(hasFile),
                color: hasFile ? color : Colors.white.withValues(alpha: 0.35),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.service,
    required this.isSelected,
    required this.onTap,
  });

  final ServiceCategory service;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localeIsAr = Directionality.of(context) == TextDirection.rtl;
    final label = localeIsAr ? service.nameAr : service.nameEn;
    final color = serviceTypeColor(service.type);
    return PressableScale(
      scale: 0.94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD4AF37), Color(0xFFE5C25B)],
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? _kGold
                : Colors.white.withValues(alpha: 0.14),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kGold.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  serviceTypeEmoji(service.type),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF1A1206)
                    : Colors.white.withValues(alpha: 0.75),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: Color(0xFF1A1206),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProviderServicesPicker extends ConsumerWidget {
  const _ProviderServicesPicker({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(providerServicesCatalogProvider);

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _IconWell(icon: Icons.handyman_outlined, color: Color(0xFF34C759)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.providerServices,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.providerServicesHint,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            if (catalog.hasValue)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kGold.withValues(alpha: 0.35)),
                ),
                child: Text(
                  l10n.selectedCount(selected.length),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kGold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    return _GlassCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 14),
          catalog.when(
            loading: () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 6; i++)
                  Container(
                    width: 96,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.somethingWentWrong,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                PressableScale(
                  scale: 0.95,
                  onTap: () =>
                      ref.invalidate(providerServicesCatalogProvider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      l10n.tryAgain,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            data: (services) {
              final sorted = [...services]
                ..sort(
                  (a, b) =>
                      _serviceRank(a.type).compareTo(_serviceRank(b.type)),
                );
              final allSelected =
                  sorted.isNotEmpty && selected.length == sorted.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: PressableScale(
                      scale: 0.95,
                      onTap: () {
                        if (allSelected) {
                          for (final s in sorted) {
                            if (selected.contains(s.type.name)) {
                              onToggle(s.type.name);
                            }
                          }
                        } else {
                          for (final s in sorted) {
                            if (!selected.contains(s.type.name)) {
                              onToggle(s.type.name);
                            }
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: allSelected
                              ? _kGold.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: allSelected
                                ? _kGold.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              allSelected
                                  ? Icons.remove_done_rounded
                                  : Icons.done_all_rounded,
                              size: 14,
                              color: allSelected
                                  ? _kGold
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.selectAll,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: allSelected
                                    ? _kGold
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final service in sorted)
                        _ServiceChip(
                          service: service,
                          isSelected: selected.contains(service.type.name),
                          onTap: () => onToggle(service.type.name),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  const _PremiumField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 15,
        ),
        prefixIcon: Container(
          width: 40,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: _kGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _kGold, size: 20),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _kGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
      ),
    );
  }
}

class _PrefToggleCard extends StatelessWidget {
  const _PrefToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Row(
        children: [
          _IconWell(icon: icon, color: _kGold),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _kGold,
            activeTrackColor: _kGold.withValues(alpha: 0.3),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _kGold, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white24,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFF2DD4BF)],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF0A0614)
                  : Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}