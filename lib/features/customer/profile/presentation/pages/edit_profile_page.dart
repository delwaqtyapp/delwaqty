import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/utils/validators.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/features/customer/profile/presentation/widgets/avatar_picker.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';

/// Full-screen edit profile (replaces the old bottom sheet): avatar with a
/// camera button, name, username, read-only phone, date of birth and save.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final User user;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;
  DateTime? _selectedDate;
  bool _saving = false;
  bool _uploading = false;
  AppLocalizations get l10n => AppLocalizations.of(context);
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName ?? '');
    _usernameController = TextEditingController(
      text: widget.user.username ?? '',
    );
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _selectedDate = widget.user.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();

    if (username.isNotEmpty && !AppValidators.isValidUsername(username)) {
      setState(() {
        _saving = false;
        _errorMessage = l10n.usernameInvalid;
      });
      return;
    }

    final data = <String, dynamic>{};
    if (name.isNotEmpty) {
      data['full_name'] = name;
    }
    data['username'] = username.isEmpty ? null : username;

    try {
      if (data.isNotEmpty) {
        await ref
            .read(updateProfileUseCaseProvider)
            .call(userId: widget.user.id, data: data);
      }
      final dobChanged = _selectedDate != widget.user.dateOfBirth;
      if (dobChanged) {
        await ref
            .read(updateDateOfBirthUseCaseProvider)
            .call(userId: widget.user.id, dateOfBirth: _selectedDate);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = e.toString().contains('users_username_unique_idx')
              ? l10n.usernameTaken
              : appErrorText(context, e);
        });
      }
    }
  }

  Widget _field({required IconData icon, required Widget child}) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 14, 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, {String? prefix, String? helper}) =>
      InputDecoration(
        labelText: label,
        prefixText: prefix,
        helperText: helper,
        helperMaxLines: 3,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = this.l10n;
    final cs = context.colorScheme;
    final live = ref.watch(watchProfileUseCaseProvider(widget.user.id)).value;
    final avatarUrl = (live ?? widget.user).avatarUrl;
    final initial = (widget.user.fullName?.isNotEmpty ?? false)
        ? widget.user.fullName![0].toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.brandGold,
                                    AppColors.brandViolet,
                                    AppColors.brandPurple,
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 56,
                                backgroundColor: cs.primary,
                                foregroundImage:
                                    avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: Text(
                                  initial,
                                  style: context.textTheme.headlineMedium
                                      ?.copyWith(
                                        color: cs.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              bottom: 0,
                              end: 0,
                              child: Semantics(
                                button: true,
                                label: l10n.takePhoto,
                                child: GestureDetector(
                                  onTap: _uploading
                                      ? null
                                      : () => pickAndUploadAvatar(
                                          context: context,
                                          ref: ref,
                                          userId: widget.user.id,
                                          l10n: l10n,
                                          onBusy: (b) {
                                            if (mounted) {
                                              setState(() => _uploading = b);
                                            }
                                          },
                                        ),
                                  child: Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cs.primary,
                                      border: Border.all(
                                        color: cs.surface,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: _uploading
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: cs.onPrimary,
                                            ),
                                          )
                                        : Icon(
                                            Icons.camera_alt_rounded,
                                            size: 16,
                                            color: cs.onPrimary,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.errorContainer.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _field(
                        icon: Icons.person_outline_rounded,
                        child: TextField(
                          controller: _nameController,
                          enabled: !_saving,
                          decoration: _deco(l10n.fullName),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        icon: Icons.alternate_email_rounded,
                        child: TextField(
                          controller: _usernameController,
                          enabled: !_saving,
                          decoration: _deco(l10n.username),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        icon: Icons.phone_outlined,
                        child: TextField(
                          controller: _phoneController,
                          readOnly: true,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          decoration: _deco(
                            l10n.phone,
                            helper: l10n.phoneChangeUnavailable,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _saving
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate ?? DateTime(2000),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                  helpText: l10n.dateOfBirth,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                    );
                                  });
                                }
                              },
                        child: _field(
                          icon: Icons.cake_outlined,
                          child: InputDecorator(
                            decoration: _deco(l10n.dateOfBirth),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedDate == null
                                        ? l10n.notSet
                                        : _formatDate(_selectedDate!),
                                    style: context.textTheme.bodyLarge,
                                  ),
                                ),
                                if (_selectedDate != null)
                                  IconButton(
                                    tooltip: l10n.clear,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _saving
                                        ? null
                                        : () => setState(
                                            () => _selectedDate = null,
                                          ),
                                    icon: const Icon(Icons.clear, size: 18),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: Text(
                          l10n.dateOfBirthPrivacy,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(l10n.saveChanges),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
