import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/service_audio_logs/domain/entities/service_audio_log.dart';
import 'package:delwaqty/features/customer/service_audio_logs/presentation/service_audio_log_providers.dart';

class AudioRecordingDialog extends ConsumerStatefulWidget {

  const AudioRecordingDialog({
    super.key,
    required this.orderId,
    required this.userId,
    this.providerId,
  });
  final String orderId;
  final String userId;
  final String? providerId;

  @override
  ConsumerState<AudioRecordingDialog> createState() => _AudioRecordingDialogState();
}

class _AudioRecordingDialogState extends ConsumerState<AudioRecordingDialog>
    with SingleTickerProviderStateMixin {
  bool _consented = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _logId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).error)),
        );
      }
      return;
    }

    final repo = ref.read(serviceAudioLogRepositoryProvider);
    final log = ServiceAudioLog(
      id: supabaseClient.storage.from('service-audio-logs').toString(),
      orderId: widget.orderId,
      userId: widget.userId,
      providerId: widget.providerId,
      createdAt: DateTime.now(),
    );

    _logId = log.id;
    await repo.createLog(log);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final duration = _elapsedSeconds;

    if (_logId != null) {
      final repo = ref.read(serviceAudioLogRepositoryProvider);
      await repo.updateAudioUrl(_logId!, '', duration, AudioLogStatus.completed);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  SupabaseClient get supabaseClient => Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!_consented) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.security, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(l10n.serviceAudioLogs),
          ],
        ),
        content: Text(l10n.recordingConsent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _consented = true);
              _startRecording();
            },
            child: Text(l10n.ok),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.1 + _pulseAnimation.value * 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  size: 40,
                  color: colorScheme.error,
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
            style: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.serviceAudioLogs,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop),
              label: Text(l10n.stopAudioRecording),
            ),
          ),
        ],
      ),
    );
  }
}
