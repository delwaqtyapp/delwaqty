import 'package:delwaqty/core/utils/avatar_initial.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:delwaqty/features/admin/presentation/widgets/admin_states.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

class AdminVerificationsWebPage extends StatefulWidget {
  const AdminVerificationsWebPage({super.key});

  @override
  State<AdminVerificationsWebPage> createState() =>
      _AdminVerificationsWebPageState();
}

class _AdminVerificationsWebPageState extends State<AdminVerificationsWebPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;
  String? _processingId;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('verification_status', 'pending')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(response);
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = appErrorText(context, e);
        });
      }
    }
  }

  Future<void> _approve(String userId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _processingId = userId);
    try {
      await _client
          .from('users')
          .update({'verification_status': 'approved'}).eq('id', userId);
      setState(() => _requests.removeWhere((r) => r['id'] == userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.userApproved),
            backgroundColor: AppColors.successLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appErrorText(context, e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _reject(String userId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _processingId = userId);
    try {
      await _client
          .from('users')
          .update({'verification_status': 'rejected'}).eq('id', userId);
      setState(() => _requests.removeWhere((r) => r['id'] == userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.userRejected),
            backgroundColor: AppColors.warningLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appErrorText(context, e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: l10n.adminVerifications,
            subtitle: l10n.adminVerificationsSubtitle,
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _loading
                      ? ''
                      : l10n.adminPendingCount(_requests.length),
                  style: const TextStyle(
                    color: AppColors.warningLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _loading
                ? const AdminLoadingState()
                : _error != null
                    ? AdminErrorState(
                        message: appErrorText(context, _error),
                        onRetry: _loadRequests,
                      )
                    : _requests.isEmpty
                        ? AdminEmptyState(
                            message: l10n.adminVerificationsEmpty,
                            icon: Icons.verified_rounded,
                          )
                        : _buildList(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppLocalizations l10n) {
    return ListView.builder(
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _VerificationCard(
            request: request,
            isProcessing: _processingId == request['id'],
            onApprove: () => _approve(request['id']),
            onReject: () => _reject(request['id']),
          ),
        );
      },
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.request,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> request;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = request['full_name'] ?? 'Unknown';
    final email = request['email'] ?? '';
    final role = request['role'] ?? request['user_type'] ?? 'unknown';
    final idCardUrl = request['id_card_url'];
    final profilePhotoUrl = request['profile_photo_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.brandPurple.withValues(alpha: 0.1),
            backgroundImage:
                profilePhotoUrl != null ? NetworkImage(profilePhotoUrl) : null,
            child: profilePhotoUrl == null
                ? Text(
                    safeInitial(name),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandPurple,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _roleColor(role).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role.toString().toUpperCase(),
                        style: TextStyle(
                          color: _roleColor(role),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (idCardUrl != null)
                      GestureDetector(
                        onTap: () => _showDocument(context, idCardUrl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'VIEW ID',
                            style: TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isProcessing)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              children: [
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorLight,
                    side: const BorderSide(color: Color(0xFFC62828)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(l10n.reject),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.successLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(l10n.approve),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _roleColor(String role) => switch (role) {
    'merchant' => const Color(0xFF8B5CF6),
    'driver' => const Color(0xFFFF9500),
    'provider' => const Color(0xFF34C759),
    'delivery' => const Color(0xFFFF9500),
    _ => const Color(0xFF4A90D9),
  };

  void _showDocument(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
