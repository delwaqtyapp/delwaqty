import 'dart:io';
import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverOnboardingPage extends StatefulWidget {
  const DriverOnboardingPage({super.key});

  @override
  State<DriverOnboardingPage> createState() => _DriverOnboardingPageState();
}

class _DriverOnboardingPageState extends State<DriverOnboardingPage> {
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
      final userId = _supabase.auth.currentUser!.id;
      final fileName = 'driver_licenses/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await _licenseImage!.readAsBytes();
      await _supabase.storage.from('driver-documents').uploadBinary(fileName, fileBytes);
      final filePath = 'driver-documents/$fileName';
      final fileUrl = _supabase.storage.from('driver-documents').getPublicUrl(filePath);

      await _supabase
          .rpc('upsert_driver_document', params: {
        'p_driver_id': userId,
        'p_doc_type': 'license',
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
        setState(() => _licenseError = 'Upload failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
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
      final userId = _supabase.auth.currentUser!.id;
      final fileName = 'driver_vehicles/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await _vehicleImage!.readAsBytes();
      await _supabase.storage.from('driver-documents').uploadBinary(fileName, fileBytes);
      final filePath = 'driver-documents/$fileName';
      final fileUrl = _supabase.storage.from('driver-documents').getPublicUrl(filePath);

      await _supabase
          .rpc('upsert_driver_document', params: {
        'p_driver_id': userId,
        'p_doc_type': 'vehicle',
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
        setState(() => _vehicleError = 'Upload failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Driver Registration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
            if (_isUploading) const Center(child: CircularProgressIndicator()) else ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
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