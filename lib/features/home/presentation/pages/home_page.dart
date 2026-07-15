import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_rounded,
                size: 80,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.welcome,
                style: context.textTheme.headlineMedium?.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.appTitle,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
