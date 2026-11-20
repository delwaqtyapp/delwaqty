import 'package:flutter/material.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Read-only operational access screen for the Delivery application.
///
/// Per platform architecture, RBAC administration (roles, permissions, region
/// authority, account creation) lives ONLY in DelwaQty Admin. This screen
/// shows the Delivery user's current operational role/status and a clear
/// pointer to Admin for any administrative action. It performs NO mutation.
class DriverAccessPage extends ConsumerWidget {
  const DriverAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final userId =
        authState is AuthAuthenticated ? authState.user.id : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deliveryAccess)),
      body: userId == null
          ? Center(child: Text(l10n.pleaseLogIn))
          : _AccessBody(userId: userId),
    );
  }
}

class _AccessBody extends StatefulWidget {
  const _AccessBody({required this.userId});
  final String userId;

  @override
  State<_AccessBody> createState() => _AccessBodyState();
}

class _AccessBodyState extends State<_AccessBody> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() {
    return Supabase.instance.client
        .from('users')
        .select('role, role_key, status')
        .eq('id', widget.userId)
        .maybeSingle();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: PremiumEmptyState(
              icon: Icons.error_outline,
              title: l10n.error,
              message: appErrorText(context, snap.error!),
              actionLabel: l10n.retry,
              onAction: () => setState(() => _future = _load()),
            ),
          );
        }
        final data = snap.data;
        final role = (data?['role_key'] as String?) ??
            (data?['role'] as String?) ??
            'delivery';
        final status = (data?['status'] as String?) ?? 'active';
        final isOwner = role == 'owner';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.delivery_dining_rounded),
                title: Text(l10n.deliveryAccessSubtitle),
                subtitle: Text(l10n.delivery),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row(label: l10n.accessRole, value: role),
                    const SizedBox(height: 8),
                    _Row(label: l10n.accessStatus, value: status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isOwner)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.ownerFullControl),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.accessManagedInAdmin),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        Chip(label: Text(value)),
      ],
    );
  }
}
