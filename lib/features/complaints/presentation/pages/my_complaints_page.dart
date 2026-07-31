import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/complaints/presentation/complaints_providers.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class MyComplaintsPage extends ConsumerStatefulWidget {
  const MyComplaintsPage({super.key});

  @override
  ConsumerState<MyComplaintsPage> createState() => _MyComplaintsPageState();
}

class _MyComplaintsPageState extends ConsumerState<MyComplaintsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final complaintsAsync = ref.watch(myComplaintsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).myComplaints)),
      body: complaintsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: e.toString(),
        ),
        data: (complaints) {
          if (complaints.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.shield_outlined,
              title: l10n.noComplaints,
              message: l10n.noComplaintsDescription,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final c = complaints[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnimatedFadeIn(
                  child: GlassCard(
                    borderRadius: 16,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.status == 'resolved' ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          c.status == 'resolved' ? Icons.check_circle : Icons.pending,
                          color: c.status == 'resolved' ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(c.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Status: ${c.status}'),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
