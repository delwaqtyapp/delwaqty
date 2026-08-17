import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/escalation/presentation/escalation_providers.dart';
import 'package:delwaqty/features/escalation/domain/entities/escalation_event.dart';
import 'package:delwaqty/shared/widgets/glass_card.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminEscalationsPage extends ConsumerStatefulWidget {
  const AdminEscalationsPage({super.key});

  @override
  ConsumerState<AdminEscalationsPage> createState() =>
      _AdminEscalationsPageState();
}

class _AdminEscalationsPageState extends ConsumerState<AdminEscalationsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final eventsAsync = ref.watch(escalationEventsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.escalationQueueTitle)),
      body: eventsAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: e.toString(),
        ),
        data: (events) {
          if (events.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.trending_up_rounded,
              title: l10n.escalationPending,
              message: l10n.noEscalationsDescription,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _EscalationTile(event: event, cs: cs, l10n: l10n);
            },
          );
        },
      ),
    );
  }
}

class _EscalationTile extends StatelessWidget {
  final EscalationEvent event;
  final ColorScheme cs;
  final AppLocalizations l10n;

  const _EscalationTile({
    required this.event,
    required this.cs,
    required this.l10n,
  });

  String _scopeLabel(String? scope, AppLocalizations l10n) {
    switch (scope) {
      case 'unassigned':
        return l10n.escalationUnassigned;
      case 'scoped':
        return l10n.escalationScoped;
      case 'global':
        return l10n.escalationGlobal;
      case 'owner':
        return l10n.escalationOwnerQueue;
      default:
        return scope ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedFadeIn(
        child: GlassCard(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.swap_vert_circle_rounded, color: cs.primary),
            ),
            title: Text(
              '${event.entityType} · ${event.createdAt.toLocal()}'.trim(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${_scopeLabel(event.previousScope, l10n)} → '
              '${_scopeLabel(event.newScope, l10n)}\n${event.reason}',
            ),
          ),
        ),
      ),
    );
  }
}
