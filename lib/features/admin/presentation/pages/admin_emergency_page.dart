import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';
import 'package:delwaqty/features/safety/domain/entities/sos_alert.dart';
import 'package:delwaqty/services/realtime/realtime_service.dart';
import 'package:delwaqty/services/realtime/realtime_channel_constants.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

class AdminEmergencyPage extends ConsumerStatefulWidget {
  const AdminEmergencyPage({super.key});

  @override
  ConsumerState<AdminEmergencyPage> createState() =>
      _AdminEmergencyPageState();
}

class _AdminEmergencyPageState extends ConsumerState<AdminEmergencyPage> {
  List<SosAlert> _activeSos = [];
  StreamSubscription<RealtimeChannel>? _channelSub;
  bool _loadingSos = true;

  @override
  void initState() {
    super.initState();
    _loadActiveSos();
    _subscribeRealtime();
  }

  Future<void> _loadActiveSos() async {
    setState(() => _loadingSos = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final rows = await client
          .from('sos_alerts')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);
      final alerts = (rows as List<dynamic>)
          .map((e) => SosAlert.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _activeSos = alerts;
          _loadingSos = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSos = false);
    }
  }

  void _subscribeRealtime() {
    final rt = ref.read(realtimeServiceProvider);
    rt.subscribe(
      channelName: RealtimeChannels.sosAlerts,
      opts: [
        RealtimeChannelFilter(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sos_alerts',
          callback: (payload) {
            final kind = payload.newRecord['status'] as String?;
            if (kind != null && (kind == 'active' || kind == 'escalated')) {
              _loadActiveSos();
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              _loadActiveSos();
            }
          },
        ),
      ],
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _channelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final alertsAsync = ref.watch(operationalAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminEmergency),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(operationalAlertsProvider);
              _loadActiveSos();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(operationalAlertsProvider);
          await _loadActiveSos();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            AnimatedFadeIn(
              child: Text(
                l10n.activeSosCalls,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingSos)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: AppLoaderCircular(),
                ),
              )
            else if (_activeSos.isEmpty)
              AnimatedFadeIn(
                child: PremiumCard(
                  child: PremiumEmptyState(
                    icon: Icons.emergency_rounded,
                    title: l10n.noActiveSosCalls,
                    message: l10n.allUsersSafe,
                  ),
                ),
              )
            else
              ...List.generate(_activeSos.length, (i) {
                final sos = _activeSos[i];
                return AnimatedFadeIn(
                  delay: Duration(milliseconds: i * 60),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: _EmergencyCard(sos: sos, l10n: l10n),
                  ),
                );
              }),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 150),
              child: Text(
                l10n.operationalAlertsTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            alertsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: AppLoaderCircular(),
                ),
              ),
              error: (e, _) => PremiumCard(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoadingMetrics,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(operationalAlertsProvider),
                ),
              ),
              data: (alerts) {
                final critical = alerts
                    .where(
                      (a) => a.severity.toLowerCase() == 'critical' ||
                          a.severity.toLowerCase() == 'high',
                    )
                    .toList();
                if (critical.isEmpty) {
                  return PremiumCard(
                    child: PremiumEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: l10n.noCriticalAlerts,
                      message: l10n.noCriticalIssues,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < critical.length; i++)
                      AnimatedFadeIn(
                        delay: Duration(milliseconds: 200 + i * 50),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: i < critical.length - 1 ? 8 : 0,
                          ),
                          child: _AlertCard(alert: critical[i], cs: cs),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.sos, required this.l10n});

  final SosAlert sos;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      radius: AppSpacing.radiusCard,
      color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sos_rounded,
              color: Color(0xFFFF3B30),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sosAlertType(sos.alertType.name),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                if (sos.address != null)
                  Text(
                    sos.address!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  l10n.sosUserLabel(sos.userId),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  l10n.sosRideInfo(sos.rideId, _formatTime(sos.createdAt)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              l10n.activeStat,
              style: const TextStyle(
                color: Color(0xFFFF3B30),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.timeNow;
    if (diff.inMinutes < 60) return l10n.sinceMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.sinceHours(diff.inHours);
    return l10n.sinceDays(diff.inDays);
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.cs});
  final OperationalAlert alert;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      radius: AppSpacing.radiusCard,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_rounded,
              color: Color(0xFFFF3B30),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  alert.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}