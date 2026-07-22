import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final a = activities[index];
          return ListTile(
            leading: Icon(
              a.current ? Icons.check_circle : Icons.history_rounded,
              color: a.current ? Colors.green : cs.onSurfaceVariant,
            ),
            title: Text(a.device),
            subtitle: Text('${a.ip} • ${a.time}'),
            trailing: a.current
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.currentSession,
                      style: TextStyle(color: Colors.green, fontSize: 12),
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
  final String device;
  final String ip;
  final String time;
  final bool current;

  const _LoginActivity({
    required this.device,
    required this.ip,
    required this.time,
    required this.current,
  });
}
