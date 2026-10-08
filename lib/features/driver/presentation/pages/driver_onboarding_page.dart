import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

class DriverOnboardingPage extends ConsumerStatefulWidget {
  const DriverOnboardingPage({super.key});

  @override
  ConsumerState<DriverOnboardingPage> createState() => _DriverOnboardingPageState();
}

class _DriverOnboardingPageState extends ConsumerState<DriverOnboardingPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  File? _licenseImage;
  File? _vehicleImage;
  String? _licenseError;
  String? _vehicleError;
  bool _isUploading = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickLicenseImage() async {
    final pickedFile = await FilePicker.pickFile(
      type: FileType.image,
    );

    if (pickedFile != null && pickedFile.path != null) {
      setState(() => _licenseImage = File(pickedFile.path!));
      _licenseError = null;
    }
  }

  Future<void> _pickVehicleImage() async {
    final pickedFile = await FilePicker.pickFile(
      type: FileType.image,
    );

    if (pickedFile != null && pickedFile.path != null) {
      setState(() => _vehicleImage = File(pickedFile.path!));
      _vehicleError = null;
    }
  }

  Future<void> _uploadLicense() async {
    final l10n = AppLocalizations.of(context);
    if (_licenseImage == null) return;
    setState(() => _isUploading = true);
    try {
      final authId = _supabase.auth.currentUser?.id;
      if (authId == null) return;
      // upsert_driver_document keys on driver_documents.driver_id which
      // REFERENCES drivers(id) — NOT the auth uid. Passing the uid made
      // every upload fail with a foreign-key violation.
      final profileAsync = await ref.read(driverProfileProvider(authId).future);
      final driverId = profileAsync?.id;
      if (driverId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToLoad)),
          );
        }
        return;
      }
      // Storage RLS requires the SECOND path segment to be the driver id
      // (064_driver_documents.sql), so the key is <folder>/<drivers.id>/…
      final fileName =
          'driver_licenses/$driverId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await _licenseImage!.readAsBytes();
      await _supabase.storage
          .from('driver-documents')
          .uploadBinary(fileName, fileBytes);
      // The bucket is PRIVATE, so a public URL cannot be read by anyone;
      // store a signed URL that the admin console can open.
      final fileUrl = await _supabase.storage
          .from('driver-documents')
          .createSignedUrl(fileName, 3600);

      await _supabase
          .rpc('upsert_driver_document', params: {
        'p_driver_id': driverId,
        'p_doc_type': 'driving_license',
        'p_file_url': fileUrl,
        'p_file_name': 'license.jpg',
        'p_file_size': _licenseImage!.lengthSync(),
        'p_expires_at': null,
      });

      if (mounted) {
        setState(() {
          _licenseError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.documentUploaded)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _licenseError = appErrorText(context, e));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErrorText(context, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadVehicle() async {
    final l10n = AppLocalizations.of(context);
    if (_vehicleImage == null) return;
    setState(() => _isUploading = true);
    try {
      final authId = _supabase.auth.currentUser?.id;
      if (authId == null) return;
      // upsert_driver_document keys on driver_documents.driver_id which
      // REFERENCES drivers(id) — NOT the auth uid. Passing the uid made
      // every upload fail with a foreign-key violation.
      final profileAsync = await ref.read(driverProfileProvider(authId).future);
      final driverId = profileAsync?.id;
      if (driverId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.failedToLoad)),
          );
        }
        return;
      }
      // Storage RLS requires the SECOND path segment to be the driver id
      // (064_driver_documents.sql), so the key is <folder>/<drivers.id>/…
      final fileName =
          'driver_vehicles/$driverId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await _vehicleImage!.readAsBytes();
      await _supabase.storage
          .from('driver-documents')
          .uploadBinary(fileName, fileBytes);
      // The bucket is PRIVATE, so a public URL cannot be read by anyone;
      // store a signed URL that the admin console can open.
      final fileUrl = await _supabase.storage
          .from('driver-documents')
          .createSignedUrl(fileName, 3600);

      await _supabase
          .rpc('upsert_driver_document', params: {
        'p_driver_id': driverId,
        'p_doc_type': 'vehicle_registration',
        'p_file_url': fileUrl,
        'p_file_name': 'vehicle.jpg',
        'p_file_size': _vehicleImage!.lengthSync(),
        'p_expires_at': null,
      });

      if (mounted) {
        setState(() {
          _vehicleError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.documentUploaded)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _vehicleError = appErrorText(context, e));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErrorText(context, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Finishes onboarding for real.
  ///
  /// The button used to be a bare `Navigator.pop()`, so
  /// `complete_driver_onboarding` was never called and
  /// drivers.onboarding_completed stayed false for every driver who
  /// onboarded through the app.
  Future<void> _completeOnboarding() async {
    final l10n = AppLocalizations.of(context);
    final authId = _supabase.auth.currentUser?.id;
    if (authId == null) return;

    setState(() => _isUploading = true);
    try {
      final profile =
          await ref.read(driverProfileProvider(authId).future);
      final driverId = profile?.id;
      if (driverId != null) {
        await ref
            .read(driverRepositoryProvider)
            .completeOnboarding(driverId);
        ref.invalidate(driverProfileProvider(authId));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onboardingCompleted)),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrong)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingTitle),
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.onboardingTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // License document section
            _buildDocumentSection(
              'License',
              Icons.description,
              _licenseImage,
              _licenseError,
              _pickLicenseImage,
              _uploadLicense,
            ),
            const SizedBox(height: 24),
            // Vehicle document section
            _buildDocumentSection(
              'Vehicle',
              Icons.directions_car,
              _vehicleImage,
              _vehicleError,
              _pickVehicleImage,
              _uploadVehicle,
            ),
            const SizedBox(height: 40),
            if (_isUploading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _completeOnboarding,
                child: Text(l10n.complete),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection(
    String title,
    IconData icon,
    File? image,
    String? error,
    VoidCallback onPick,
    VoidCallback onUpload,
  ) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (image != null)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.file(image),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                ),
                child: const Center(
                  child: Text(
                    'Upload Image',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_file),
                  label: Text(l10n.upload),
                ),
                if (!_isUploading)
                  ElevatedButton.icon(
                    onPressed: onUpload,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward),
                    label: _isUploading ? Text(l10n.uploading) : Text(l10n.upload),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}