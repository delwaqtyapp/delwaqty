import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

void showEmailVerifiedDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(
        Icons.mark_email_read_rounded,
        color: AppColors.brandPurple,
        size: 56,
      ),
      title: Center(child: Text(l10n.emailVerifiedTitle)),
      content: Text(
        l10n.emailVerifiedBody,
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.emailVerifiedOk),
        ),
      ],
    ),
  );
}

Future<void> handleEmailConfirmedDeepLink(
  WidgetRef ref, {
  required GlobalKey<NavigatorState> navigatorKey,
}) async {
  await ref.read(authStateProvider.notifier).checkAuthStatus();
  final state = ref.read(authStateProvider);
  final context = navigatorKey.currentContext;
  if (state is AuthAuthenticated && context != null && context.mounted) {
    showEmailVerifiedDialog(context);
  }
}