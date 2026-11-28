import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';

/// Dedicated language picker: choose Arabic or English, then Apply.
/// The choice is held locally until Apply so a stray tap never flips the app.
class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});

  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage> {
  String? _picked;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = context.colorScheme;
    final current = ref.watch(localeProvider).languageCode;
    final selected = _picked ?? current;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.language)),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        const _LanguageArt(),
                        const SizedBox(height: 20),
                        Text(
                          l10n.chooseAppLanguage,
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.languageChangeAnytime,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _LanguageOption(
                          code: 'ar',
                          label: l10n.arabicLanguageName,
                          selected: selected == 'ar',
                          onTap: () => setState(() => _picked = 'ar'),
                        ),
                        const SizedBox(height: 12),
                        _LanguageOption(
                          code: 'en',
                          label: l10n.englishLanguageName,
                          selected: selected == 'en',
                          onTap: () => setState(() => _picked = 'en'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (selected != current) {
                        await ref
                            .read(localeProvider.notifier)
                            .setLocale(Locale(selected));
                      }
                      if (mounted) _close();
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l10n.apply),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.08)
                : cs.surfaceContainerLowest,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(
              color: selected
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.35),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(36, 26),
                painter: _FlagPainter(code),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny painted flags (Egypt, United Kingdom): no image assets, no emoji
/// fonts, identical on every device.
class _FlagPainter extends CustomPainter {
  const _FlagPainter(this.code);

  final String code;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide * 0.15),
    );
    canvas.save();
    canvas.clipRRect(r);
    final w = size.width;
    final h = size.height;
    Paint p(int c) => Paint()..color = Color(c);
    if (code == 'ar') {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 3), p(0xFFCE1126));
      canvas.drawRect(Rect.fromLTWH(0, h / 3, w, h / 3), p(0xFFFFFFFF));
      canvas.drawRect(Rect.fromLTWH(0, 2 * h / 3, w, h / 3), p(0xFF000000));
      canvas.drawCircle(Offset(w / 2, h / 2), h * 0.11, p(0xFFC09300));
    } else {
      canvas.drawRect(Offset.zero & size, p(0xFF012169));
      final white = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = h * 0.24;
      final red = Paint()
        ..color = const Color(0xFFC8102E)
        ..strokeWidth = h * 0.10;
      canvas.drawLine(Offset.zero, Offset(w, h), white);
      canvas.drawLine(Offset(w, 0), Offset(0, h), white);
      canvas.drawLine(Offset.zero, Offset(w, h), red);
      canvas.drawLine(Offset(w, 0), Offset(0, h), red);
      canvas.drawRect(Rect.fromLTWH(w * 0.4, 0, w * 0.2, h), p(0xFFFFFFFF));
      canvas.drawRect(Rect.fromLTWH(0, h * 0.34, w, h * 0.32), p(0xFFFFFFFF));
      canvas.drawRect(Rect.fromLTWH(w * 0.44, 0, w * 0.12, h), p(0xFFC8102E));
      canvas.drawRect(Rect.fromLTWH(0, h * 0.40, w, h * 0.20), p(0xFFC8102E));
    }
    canvas.restore();
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x33000000)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _FlagPainter old) => old.code != code;
}

class _LanguageArt extends StatelessWidget {
  const _LanguageArt();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    Widget card(String glyph, Color bg, Color fg, double angle) {
      return Transform.rotate(
        angle: angle,
        child: Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            glyph,
            style: TextStyle(
              fontSize: 44,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 170,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            end: 8,
            top: 22,
            child: card(
              'A',
              cs.surfaceContainerHighest,
              cs.primary.withValues(alpha: 0.75),
              0.12,
            ),
          ),
          PositionedDirectional(
            start: 8,
            top: 4,
            child: card('ع', cs.primary, cs.onPrimary, -0.1),
          ),
        ],
      ),
    );
  }
}
