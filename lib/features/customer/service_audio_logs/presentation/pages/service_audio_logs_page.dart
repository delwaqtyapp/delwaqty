import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/service_audio_logs/presentation/service_audio_log_providers.dart';
import 'package:delwaqty/features/customer/service_audio_logs/domain/entities/service_audio_log.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ServiceAudioLogsPage extends ConsumerWidget {
  const ServiceAudioLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final logsAsync = ref.watch(serviceAudioLogsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.serviceAudioLogs)),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(l10n.error),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(serviceAudioLogsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_off_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noAudioRecordings,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final log = logs[index];
              return _AudioLogCard(log: log, l10n: l10n);
            },
          );
        },
      ),
    );
  }
}

class _AudioLogCard extends StatelessWidget {

  const _AudioLogCard({required this.log, required this.l10n});
  final ServiceAudioLog log;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isCompleted = log.status == AudioLogStatus.completed;
    final icon = isCompleted ? Icons.check_circle : Icons.hourglass_bottom;
    final color = isCompleted ? colorScheme.primary : colorScheme.tertiary;
    final durationText = log.durationSeconds != null
        ? '${log.durationSeconds! ~/ 60}:${(log.durationSeconds! % 60).toString().padLeft(2, '0')}'
        : '--:--';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.audioLogsForOrder}: ${log.orderId.length > 8 ? log.orderId.substring(0, 8) : log.orderId}...',
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(log.createdAt),
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusChip(status: log.status, l10n: l10n),
                      const SizedBox(width: 8),
                      Icon(Icons.timer_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        durationText,
                        style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (log.audioUrl != null)
              IconButton(
                icon: Icon(Icons.play_circle_filled, color: colorScheme.primary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Audio: ${log.audioUrl}')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {

  const _StatusChip({required this.status, required this.l10n});
  final AudioLogStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String label;
    Color color;

    switch (status) {
      case AudioLogStatus.completed:
        label = 'Completed';
        color = colorScheme.primary;
      case AudioLogStatus.recording:
        label = 'Recording';
        color = colorScheme.error;
      case AudioLogStatus.failed:
        label = 'Failed';
        color = colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
