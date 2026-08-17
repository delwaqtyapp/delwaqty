import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
        authenticated: (_) => context.go('/home'),
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
      backgroundColor: const Color(0xFFF8F6FF),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(l10n),
                _buildProgressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildStepContent(l10n, authState),
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

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F6FF), Color(0xFFEFEBFF), Color(0xFFF5F3FF)],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          if (_currentStep > 0)
            GestureDetector(
              onTap: _prevStep,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A1035).withValues(alpha: 0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: const Color(0xFF1A1035).withValues(alpha: 0.6),
                  size: 18,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A1035).withValues(alpha: 0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: const Color(0xFF1A1035).withValues(alpha: 0.6),
                  size: 18,
                ),
              ),
            ),
          const SizedBox(width: 16),
          Text(
            l10n.register,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1035),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: List.generate(4, (i) {
          final isActive = i <= _currentStep;
          final isCurrent = i == _currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              margin: i < 3 ? const EdgeInsets.only(left: 8) : EdgeInsets.zero,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isActive
                    ? const LinearGradient(
                        colors: [AppColors.brandPurple, AppColors.brandCyan],
                      )
                    : null,
                color: isActive
                    ? null
                    : const Color(0xFF1A1035).withValues(alpha: 0.08),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.brandPurple.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(AppLocalizations l10n, AuthState authState) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_currentStep) {
        0 => _buildStepRole(l10n),
        1 => _buildStepInfo(l10n),
        2 => _buildStepPreferences(l10n),
        3 => _buildStepConfirmation(l10n, authState),
        _ => const SizedBox(),
      },
    );
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
        const SizedBox(height: 16),
        Text(
          l10n.selectAccountType,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1035),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.accountTypeDescription,
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF1A1035).withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 24),
        for (final role in roles) ...[
          _RoleOption(
            userType: role.$1,
            icon: role.$2,
            title: role.$3,
            subtitle: role.$4,
            color: role.$5,
            isSelected: _selectedRole == role.$1,
            onTap: () => setState(() => _selectedRole = role.$1),
          ),
          const SizedBox(height: 14),
        ],
        if (_selectedRole != null && _selectedRole!.requiresVerification) ...[
          const SizedBox(height: 6),
          _UploadTile(
            icon: Icons.badge_outlined,
            title: l10n.uploadIdCard,
            hint: l10n.uploadIdCardHint,
            filePath: _idCardFile?.path,
            color: const Color(0xFF007AFF),
            onTap: () => _pickDocument(documentType: 'idCard'),
          ),
          const SizedBox(height: 14),
          _UploadTile(
            icon: Icons.person_outline_rounded,
            title: l10n.uploadProfilePhoto,
            hint: l10n.uploadProfilePhotoHint,
            filePath: _profilePhotoFile?.path,
            color: const Color(0xFFAF52DE),
            onTap: () => _pickDocument(documentType: 'profilePhoto'),
          ),
          if (_selectedRole!.requiresTradeLicense) ...[
            const SizedBox(height: 14),
            _UploadTile(
              icon: Icons.description_outlined,
              title: l10n.uploadTradeLicense,
              hint: l10n.uploadTradeLicenseHint,
              filePath: _tradeLicenseFile?.path,
              color: const Color(0xFF34C759),
              onTap: () => _pickDocument(documentType: 'tradeLicense'),
            ),
          ],
          if (_selectedRole!.requiresDrivingLicense) ...[
            const SizedBox(height: 14),
            _UploadTile(
              icon: Icons.local_shipping_outlined,
              title: l10n.uploadDrivingLicense,
              hint: l10n.uploadDrivingLicenseHint,
              filePath: _drivingLicenseFile?.path,
              color: const Color(0xFFFF9500),
              onTap: () => _pickDocument(documentType: 'drivingLicense'),
            ),
          ],
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStepInfo(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n.createAccount,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1035),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fill in your details to get started',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF1A1035).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 28),
          _LightRegField(
            controller: _nameController,
            hint: l10n.fullName,
            icon: Icons.person_outline_rounded,
            validator: (v) => AppValidators.required(v),
          ),
          const SizedBox(height: 14),
          _LightRegField(
            controller: _emailController,
            hint: l10n.email,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => AppValidators.email(v),
          ),
          const SizedBox(height: 14),
          _LightRegField(
            controller: _phoneController,
            hint: l10n.phoneNumber,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _LightRegField(
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
                color: const Color(0xFF1A1035).withValues(alpha: 0.3),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _LightRegField(
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
                color: const Color(0xFF1A1035).withValues(alpha: 0.3),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStepPreferences(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Preferences',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1035),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Customize your experience',
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF1A1035).withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 28),
        _buildLanguageSelector(l10n),
        const SizedBox(height: 20),
        _buildToggleOption(
          icon: Icons.notifications_outlined,
          title: l10n.notifications,
          subtitle: 'Receive updates and offers',
          value: _notificationsEnabled,
          onChanged: (v) => setState(() => _notificationsEnabled = v),
        ),
        const SizedBox(height: 14),
        _buildToggleOption(
          icon: Icons.location_on_outlined,
          title: l10n.location,
          subtitle: 'Find nearby services',
          value: _locationEnabled,
          onChanged: (v) => setState(() => _locationEnabled = v),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildLanguageSelector(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1A1035).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LanguageOption(
              label: 'العربية',
              isSelected: _selectedLanguage == 'ar',
              onTap: () => setState(() => _selectedLanguage = 'ar'),
            ),
          ),
          Expanded(
            child: _LanguageOption(
              label: 'English',
              isSelected: _selectedLanguage == 'en',
              onTap: () => setState(() => _selectedLanguage = 'en'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1A1035).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.brandPurple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1035),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF1A1035).withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.brandPurple,
            activeTrackColor: AppColors.brandPurple.withValues(alpha: 0.3),
            inactiveTrackColor: const Color(0xFF1A1035).withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConfirmation(AppLocalizations l10n, AuthState authState) {
    return Column(
      children: [
        const SizedBox(height: 60),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, value, _) {
            return Transform.scale(
              scale: 0.5 + value * 0.5,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.brandPurple, AppColors.brandCyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandPurple.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        const Text(
          'Account Created!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1035),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Welcome to DelwaQty',
          style: TextStyle(
            fontSize: 15,
            color: const Color(0xFF1A1035).withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'كل احتياجاتك... دلوقتي',
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF1A1035).withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(AppLocalizations l10n, AuthState authState) {
    final isLoading = authState is AuthLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandPurple, Color(0xFF6B5CE7)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPurple.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading
                  ? null
                  : _currentStep < 3
                  ? _nextStep
                  : _onRegister,
              borderRadius: BorderRadius.circular(22),
              splashColor: Colors.white.withValues(alpha: 0.1),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _currentStep < 3 ? l10n.next : l10n.register,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.userType,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final UserType userType;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? color
                : const Color(0xFF1A1035).withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1035),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1A1035).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? color
                      : const Color(0xFF1A1035).withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.icon,
    required this.title,
    required this.hint,
    required this.filePath,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final String? filePath;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasFile = filePath != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasFile
                ? color.withValues(alpha: 0.6)
                : const Color(0xFF1A1035).withValues(alpha: 0.08),
            width: hasFile ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (hasFile)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(filePath!),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1035),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1A1035).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.add_circle_outline,
              color: hasFile
                  ? color
                  : const Color(0xFF1A1035).withValues(alpha: 0.3),
            ),
          ],
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
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1A1035), size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1035),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightRegField extends StatelessWidget {
  const _LightRegField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Color(0xFF1A1035), fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: const Color(0xFF1A1035).withValues(alpha: 0.3),
          fontSize: 15,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF1A1035).withValues(alpha: 0.35),
          size: 20,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFF1A1035).withValues(alpha: 0.06),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFF1A1035).withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.brandPurple,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.brandPurple, AppColors.brandCyan],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? Colors.white
                  : const Color(0xFF1A1035).withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
