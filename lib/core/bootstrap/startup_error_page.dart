import 'package:flutter/material.dart';
import 'package:delwaqty/config/config_validator.dart';

/// Full-screen page shown when the app cannot start because the
/// configuration injected via `--dart-define-from-file` is invalid.
///
/// Without this, a bad/missing `.env` silently leaves the app stuck on
/// the native splash forever.
class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({super.key, required this.result});

  final ValidationResult result;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF241E44),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFF7A5CFF),
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'خطأ في الإعدادات',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configuration Error',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final error in result.errors) ...[
                    _ErrorTile(message: error),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                  const _HintBox(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF7A5CFF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'أعد بناء التطبيق باستخدام ملف الإعدادات.\n'
        'Rebuild the app with:\n'
        'flutter run --dart-define-from-file=.env.dev',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}