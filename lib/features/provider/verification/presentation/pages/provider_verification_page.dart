import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/provider_verification_providers.dart';

class ProviderVerificationPage extends ConsumerStatefulWidget {
  const ProviderVerificationPage({super.key});

  @override
  ConsumerState<ProviderVerificationPage> createState() =>
      _ProviderVerificationPageState();
}

class _ProviderVerificationPageState
    extends ConsumerState<ProviderVerificationPage> {
  PlatformFile? _idCardFile;
  PlatformFile? _photoFile;
  bool _busy = false;
  String? _error;
  bool _submitted = false;

  Future<void> _pick(bool isIdCard) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return;
    final file = result.first;
    setState(() {
      if (isIdCard) {
        _idCardFile = file;
      } else {
        _photoFile = file;
      }
    });
  }

  Future<String> _upload(PlatformFile? file, String field) async {
    if (file == null) {
      throw Exception('$field is required');
    }
    final bytes = await file.readAsBytes();
    return ref
        .read(providerVerificationRepositoryProvider)
        .uploadDoc('${field}_${file.name}', bytes);
  }

  Future<void> _submit(bool reapply) async {
    if (_busy || _submitted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final idCardUrl = await _upload(_idCardFile, 'id_card');
      final photoUrl = await _upload(_photoFile, 'profile_photo');
      final repo = ref.read(providerVerificationRepositoryProvider);
      if (reapply) {
        await repo.reapplyVerification(idCardUrl, photoUrl);
      } else {
        final res = await repo.submitVerification(idCardUrl, photoUrl);
        if (res['ok'] == false && res['code'] == 'USE_REAPPLY') {
          await repo.reapplyVerification(idCardUrl, photoUrl);
        }
      }
      if (mounted) {
        setState(() => _submitted = true);
        ref.invalidate(providerVerificationProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents submitted for review')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerVerificationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load verification: $e'),
        ),
        data: (data) {
          final status = data['verification_status'] as String?;
          final reason = data['rejection_reason'] as String?;
          final idCard = data['id_card_url'] as String?;
          final photo = data['profile_photo_url'] as String?;
          final submitted = status == 'pending' || _submitted;
          final rejected = status == 'rejected';
          final approved = status == 'approved';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (approved)
                const Card(
                  color: Colors.green,
                  child: ListTile(
                    leading: Icon(Icons.verified, color: Colors.white),
                    title: Text(
                      'Verified',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                )
              else if (submitted)
                const Card(
                  color: Colors.orange,
                  child: ListTile(
                    leading: Icon(Icons.hourglass_top, color: Colors.white),
                    title: Text(
                      'Pending review',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                )
              else
                const Card(
                  color: Colors.grey,
                  child: ListTile(
                    title: Text('Not submitted yet'),
                  ),
                ),
              if (rejected && reason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: const Text('Rejected'),
                      subtitle: Text(reason),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('ID card'),
                subtitle: Text(_idCardFile?.name ?? idCard ?? 'Not uploaded'),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _pick(true),
                  child: const Text('Choose'),
                ),
              ),
              ListTile(
                title: const Text('Profile photo'),
                subtitle: Text(_photoFile?.name ?? photo ?? 'Not uploaded'),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _pick(false),
                  child: const Text('Choose'),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed:
                    _busy || _submitted ? null : () => _submit(rejected),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(rejected ? 'Re-apply' : 'Submit'),
              ),
            ],
          );
        },
      ),
    );
  }
}
