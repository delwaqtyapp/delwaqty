import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class LoginActivityPage extends StatelessWidget {
  const LoginActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final activities = [
      _LoginActivity(
        device: 'Android — DNP NX9',
        ip: '192.168.1.x',
        time: l10n.currentTime,
        current: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginActivity),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: activities.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final a = activities[index];
          return ListTile(
            leading: Icon(
              a.current ? Icons.check_circle : Icons.history_rounded,
              color: a.current ? AppColors.successLight : cs.onSurfaceVariant,
            ),
            title: Text(a.device),
            subtitle: Text('${a.ip} • ${a.time}'),
            trailing: a.current
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.currentSession,
                      style: const TextStyle(color: AppColors.successLight, fontSize: 12),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _LoginActivity {

  const _LoginActivity({
    required this.device,
    required this.ip,
    required this.time,
    required this.current,
  });
  final String device;
  final String ip;
  final String time;
  final bool current;
}
