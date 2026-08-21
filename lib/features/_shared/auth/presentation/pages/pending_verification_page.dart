import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class PendingVerificationPage extends ConsumerStatefulWidget {
  const PendingVerificationPage({super.key});

  @override
  ConsumerState<PendingVerificationPage> createState() =>
      _PendingVerificationPageState();
}

class _PendingVerificationPageState
    extends ConsumerState<PendingVerificationPage> {
  User? _user;
  bool _loadingUser = true;
  XFile? _idCardFile;
  XFile? _profilePhotoFile;
  bool _submitting = false;
  bool _isReapply = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      if (mounted) {
        setState(() {
          _user = user;
          _loadingUser = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingUser = false);
      }
    }
  }

  Future<void> _pickDocument({required bool isIdCard}) async {
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
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    setState(() {
      if (isIdCard) {
        _idCardFile = file;
      } else {
        _profilePhotoFile = file;
      }
    });
  }

  Future<void> _submitDocuments() async {
    final l10n = AppLocalizations.of(context);
    final user = _user;
    if (user == null) return;
    if (_idCardFile == null || _profilePhotoFile == null) {
      context.showAppSnackBar(l10n.documentsRequired);
      return;
    }
    setState(() => _submitting = true);
    try {
      final Uint8List idCardBytes = await _idCardFile!.readAsBytes();
      final Uint8List profilePhotoBytes = await _profilePhotoFile!
          .readAsBytes();
      final uploadDocument = ref.read(uploadDocumentUseCaseProvider);
      final idCardUrl = await uploadDocument(
        userId: user.id,
        bytes: idCardBytes,
        fileName: _idCardFile!.name,
      );
      final profilePhotoUrl = await uploadDocument(
        userId: user.id,
        bytes: profilePhotoBytes,
        fileName: _profilePhotoFile!.name,
      );
      if (_isReapply) {
        await ref.read(reapplyVerificationUseCaseProvider)(
          userId: user.id,
          idCardUrl: idCardUrl,
          profilePhotoUrl: profilePhotoUrl,
        );
      } else {
        await ref.read(updateProfileUseCaseProvider)(
          userId: user.id,
          data: {'id_card_url': idCardUrl, 'profile_photo_url': profilePhotoUrl},
        );
      }
      if (!mounted) return;
      final wasReapply = _isReapply;
      setState(() {
        _idCardFile = null;
        _profilePhotoFile = null;
        _isReapply = false;
      });
      await _loadUser();
      if (!mounted) return;
      context.showAppSnackBar(
        wasReapply ? l10n.reapplyVerificationSuccess : l10n.documentsUploaded,
      );
    } catch (_) {
      if (mounted) {
        context.showAppSnackBar(
          _isReapply ? l10n.verificationReapplyFailed : l10n.documentsUploadFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _needsDocuments(User user) {
    return user.idCardUrl == null || user.profilePhotoUrl == null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (previous, next) {
      next.whenOrNull(
        unauthenticated: () => context.go('/welcome'),
        error: (_) => context.go('/welcome'),
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      body: SafeArea(
        child: _loadingUser
            ? const Center(child: CircularProgressIndicator())
            : _user == null
            ? _buildLoadError(l10n, authState)
            : _user!.verificationStatus.isRejected
            ? _isReapply
                ? _needsDocuments(_user!)
                    ? _buildDocumentsFlow(l10n, authState, _user!)
                    : _buildReviewOnly(l10n, authState)
                : _buildRejected(l10n, authState, _user!)
            : _needsDocuments(_user!)
            ? _buildDocumentsFlow(l10n, authState, _user!)
            : _buildReviewOnly(l10n, authState),
      ),
    );
  }

  Widget _buildRejected(
    AppLocalizations l10n,
    AuthState authState,
    User user,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          _buildHeader(l10n),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE57373)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Color(0xFFE57373),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.verificationRejectedTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1035),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.verificationRejectedMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF1A1035).withValues(alpha: 0.6),
                  ),
                ),
                if ((user.rejectionReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE9E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.verificationRejectionReason(user.rejectionReason!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB3261E),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () {
                setState(() => _isReapply = true);
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                l10n.reapplyVerification,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLogoutButton(l10n, authState),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLoadError(AppLocalizations l10n, AuthState authState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(),
          const Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: Color(0xFF1A1035),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.errorLoading,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF1A1035).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _loadUser,
              child: Text(l10n.retry),
            ),
          ),
          const Spacer(),
          _buildLogoutButton(l10n, authState),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewOnly(AppLocalizations l10n, AuthState authState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(),
          _buildHeader(l10n),
          const Spacer(),
          _buildLogoutButton(l10n, authState),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDocumentsFlow(
    AppLocalizations l10n,
    AuthState authState,
    User user,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          _buildHeader(l10n),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF1A1035).withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.brandPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.badge_outlined,
                        color: AppColors.brandPurple,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.documentsSectionTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1035),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.documentsSectionMessage,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF1A1035).withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 18),
                _DocumentTile(
                  icon: Icons.badge_outlined,
                  title: l10n.uploadIdCard,
                  hint: l10n.uploadIdCardHint,
                  filePath: _idCardFile?.path,
                  color: const Color(0xFF007AFF),
                  onTap: () => _pickDocument(isIdCard: true),
                ),
                const SizedBox(height: 14),
                _DocumentTile(
                  icon: Icons.person_outline_rounded,
                  title: l10n.uploadProfilePhoto,
                  hint: l10n.uploadProfilePhotoHint,
                  filePath: _profilePhotoFile?.path,
                  color: const Color(0xFFAF52DE),
                  onTap: () => _pickDocument(isIdCard: false),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submitDocuments,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.submitDocuments,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildLogoutButton(l10n, authState),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandPurpleDeep, AppColors.brandCyan],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPurple.withValues(alpha: 0.3),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.hourglass_top_rounded,
            color: Colors.white,
            size: 48,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.verificationPendingTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1035),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.verificationPendingMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: const Color(0xFF1A1035).withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(AppLocalizations l10n, AuthState authState) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: authState is AuthLoading
            ? null
            : () => ref.read(authStateProvider.notifier).signOut(),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A1035),
          side: BorderSide(
            color: const Color(0xFF1A1035).withValues(alpha: 0.15),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          l10n.logout,
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F6FF),
          borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(filePath!),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1035),
                    ),
                  ),
                  const SizedBox(height: 2),
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
