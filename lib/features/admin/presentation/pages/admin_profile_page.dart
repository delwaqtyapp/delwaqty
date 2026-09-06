import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';

class AdminProfilePage extends ConsumerStatefulWidget {
  const AdminProfilePage({super.key});

  @override
  ConsumerState<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends ConsumerState<AdminProfilePage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final client = Supabase.instance.client;
      final email = client.auth.currentUser?.email ?? '';
      final isOwner = ref.watch(adminIsOwnerProvider).value ?? false;

      final result = await client.rpc('get_admin_profile', params: {
        'p_email': email,
      });

      if (mounted) {
        setState(() {
          _profile = {
            'email': email,
            'is_owner': isOwner,
            ...((result as Map<String, dynamic>?) ?? {}),
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profile = {
            'email': Supabase.instance.client.auth.currentUser?.email ?? '',
            'is_owner': false,
            'role': 'admin',
            'assigned_region': null,
            'total_earnings': 0.0,
            'region_name': null,
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminProfile),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(child: Text(l10n.error))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedFadeIn(
                        child: _buildProfileHeader(l10n, cs),
                      ),
                      const SizedBox(height: 24),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 100),
                        child: _buildRoleInfo(l10n, cs),
                      ),
                      const SizedBox(height: 24),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 200),
                        child: _buildEarningsSection(l10n, cs),
                      ),
                      const SizedBox(height: 24),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 300),
                        child: _buildRegionInfo(l10n, cs),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader(AppLocalizations l10n, ColorScheme cs) {
    final email = _profile!['email'] as String? ?? '';
    final isOwner = _profile!['is_owner'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: isOwner
                  ? Colors.amber
                  : cs.primaryContainer,
              child: Icon(
                isOwner ? Icons.star_rounded : Icons.admin_panel_settings_rounded,
                size: 40,
                color: isOwner ? Colors.amber.shade800 : cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isOwner ? l10n.ownerFullAccess : l10n.adminProfile,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleInfo(AppLocalizations l10n, ColorScheme cs) {
    final isOwner = _profile!['is_owner'] as bool? ?? false;
    final roleName = _profile!['role'] as String? ?? 'admin';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminRole,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow(
              icon: Icons.badge_rounded,
              label: l10n.adminRole,
              value: isOwner
                  ? l10n.ownerFullAccess
                  : _roleDisplayName(roleName, l10n),
              color: isOwner ? Colors.amber : cs.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsSection(AppLocalizations l10n, ColorScheme cs) {
    final earnings = (_profile!['total_earnings'] as num?)?.toDouble() ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminEarnings,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.adminEarningsDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    '${earnings.toStringAsFixed(2)} EGP',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.totalEarnings,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionInfo(AppLocalizations l10n, ColorScheme cs) {
    final regionName = _profile!['region_name'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminAssignedRegion,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow(
              icon: Icons.location_on_rounded,
              label: l10n.adminAssignedRegion,
              value: regionName ?? '-',
              color: regionName != null ? cs.primary : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _roleDisplayName(String role, AppLocalizations l10n) => switch (role) {
    'country_admin' => l10n.countryAdmin,
    'governorate_admin' => l10n.governorateAdmin,
    'center_admin' => l10n.centerAdmin,
    'village_admin' => l10n.villageAdmin,
    _ => l10n.adminRole,
  };
}
