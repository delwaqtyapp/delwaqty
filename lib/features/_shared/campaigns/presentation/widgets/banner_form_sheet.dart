import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/confirm_dialog.dart';

typedef BannerSubmitCallback = Future<void> Function({
  required String titleAr,
  String? titleEn,
  String? subtitleAr,
  String? subtitleEn,
  String? regionId,
  Uint8List? imageBytes,
  String imageExtension,
  DateTime? startsAt,
  DateTime? endsAt,
});

/// Modal bottom sheet for creating or editing a campaign banner (used by both
/// admin and provider flows).
class BannerFormSheet extends ConsumerStatefulWidget {
  const BannerFormSheet({
    super.key,
    required this.submitLabel,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.successMessage,
    required this.onSubmit,
    this.sheetTitle,
    this.initialTitleAr,
    this.initialTitleEn,
    this.initialSubtitleAr,
    this.initialSubtitleEn,
    this.initialRegionId,
    this.initialStartsAt,
    this.initialEndsAt,
  });

  final String submitLabel;
  final String confirmTitle;
  final String confirmMessage;
  final String successMessage;
  final BannerSubmitCallback onSubmit;
  final String? sheetTitle;
  final String? initialTitleAr;
  final String? initialTitleEn;
  final String? initialSubtitleAr;
  final String? initialSubtitleEn;
  final String? initialRegionId;
  final DateTime? initialStartsAt;
  final DateTime? initialEndsAt;

  static Future<bool> show(
    BuildContext context, {
    required String submitLabel,
    required String confirmTitle,
    required String confirmMessage,
    required String successMessage,
    required BannerSubmitCallback onSubmit,
    String? sheetTitle,
    String? initialTitleAr,
    String? initialTitleEn,
    String? initialSubtitleAr,
    String? initialSubtitleEn,
    String? initialRegionId,
    DateTime? initialStartsAt,
    DateTime? initialEndsAt,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BannerFormSheet(
        submitLabel: submitLabel,
        confirmTitle: confirmTitle,
        confirmMessage: confirmMessage,
        successMessage: successMessage,
        onSubmit: onSubmit,
        sheetTitle: sheetTitle,
        initialTitleAr: initialTitleAr,
        initialTitleEn: initialTitleEn,
        initialSubtitleAr: initialSubtitleAr,
        initialSubtitleEn: initialSubtitleEn,
        initialRegionId: initialRegionId,
        initialStartsAt: initialStartsAt,
        initialEndsAt: initialEndsAt,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<BannerFormSheet> createState() => _BannerFormSheetState();
}

class _BannerFormSheetState extends ConsumerState<BannerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleArController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _subtitleArController = TextEditingController();
  final _subtitleEnController = TextEditingController();

  bool _isNational = true;
  String? _selectedGovernorateId;
  DateTime? _startsAt;
  DateTime? _endsAt;
  Uint8List? _imageBytes;
  String _imageExtension = 'jpg';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _titleArController.text = widget.initialTitleAr ?? '';
    _titleEnController.text = widget.initialTitleEn ?? '';
    _subtitleArController.text = widget.initialSubtitleAr ?? '';
    _subtitleEnController.text = widget.initialSubtitleEn ?? '';
    _selectedGovernorateId = widget.initialRegionId;
    _isNational = widget.initialRegionId == null;
    _startsAt = widget.initialStartsAt?.toLocal();
    _endsAt = widget.initialEndsAt?.toLocal();
  }

  @override
  void dispose() {
    _titleArController.dispose();
    _titleEnController.dispose();
    _subtitleArController.dispose();
    _subtitleEnController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = (isStart ? _startsAt : _endsAt) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (isStart) {
        _startsAt = combined;
      } else {
        _endsAt = combined;
      }
    });
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final parts = picked.name.split('.');
      final ext = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageExtension = ext;
      });
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: widget.confirmTitle,
      message: widget.confirmMessage,
      confirmLabel: widget.submitLabel,
    );
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        titleAr: _titleArController.text.trim(),
        titleEn: _titleEnController.text.trim(),
        subtitleAr: _subtitleArController.text.trim(),
        subtitleEn: _subtitleEnController.text.trim(),
        regionId: _isNational ? null : _selectedGovernorateId,
        imageBytes: _imageBytes,
        imageExtension: _imageExtension,
        startsAt: _startsAt,
        endsAt: _endsAt,
      );
      if (!mounted) return;
      context.showAppSnackBar(widget.successMessage);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final governoratesAsync = ref.watch(governoratesProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.sheetTitle ?? l10n.createBanner,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleArController,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: l10n.bannerTitleAr,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleEnController,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.bannerTitleEn,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitleArController,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.bannerSubtitleAr,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitleEnController,
                textDirection: TextDirection.ltr,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.bannerSubtitleEn,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.targetScope,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.public_rounded),
                    label: Text(l10n.allEgypt),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(l10n.specificGovernorate),
                  ),
                ],
                selected: {_isNational},
                onSelectionChanged: _submitting
                    ? null
                    : (selection) {
                        setState(() {
                          _isNational = selection.first;
                          if (_isNational) {
                            _selectedGovernorateId = null;
                          }
                        });
                      },
              ),
              if (!_isNational) ...[
                const SizedBox(height: 12),
                governoratesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(
                    appErrorText(context, e),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  data: (governorates) => DropdownButtonFormField<String>(
                    initialValue: _selectedGovernorateId,
                    decoration: InputDecoration(
                      labelText: l10n.selectGovernorate,
                      border: const OutlineInputBorder(),
                    ),
                    items: governorates
                        .map(
                          (gov) => DropdownMenuItem<String>(
                            value: gov.id,
                            child: Text(
                              lang == 'en'
                                  ? (gov.nameEn ?? gov.nameAr)
                                  : gov.nameAr,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (val) => setState(() => _selectedGovernorateId = val),
                    validator: (val) => !_isNational && (val == null || val.isEmpty)
                        ? l10n.selectGovernorate
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.scheduleBanner,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _submitting ? null : () => _pickDateTime(isStart: true),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        _startsAt != null
                            ? '${l10n.startDate}: ${_formatDateTime(_startsAt!)}'
                            : l10n.startDate,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_startsAt != null)
                    IconButton(
                      tooltip: l10n.clear,
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _startsAt = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _pickDateTime(isStart: false),
                      icon: const Icon(Icons.event_busy_outlined),
                      label: Text(
                        _endsAt != null
                            ? '${l10n.endDate}: ${_formatDateTime(_endsAt!)}'
                            : l10n.endDate,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_endsAt != null)
                    IconButton(
                      tooltip: l10n.clear,
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _endsAt = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(l10n.selectBannerImage),
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 12),
                Stack(
                  alignment: AlignmentDirectional.topEnd,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _imageBytes!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          tooltip: l10n.clear,
                          color: Colors.white,
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _imageBytes = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _handleSubmit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
