import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Caption under a weekly-hours row for non-standard windows: overnight
/// (close before open, ends the next calendar day) and 24h (open == close).
/// Renders nothing for plain same-day windows. HH:MM strings compare
/// lexicographically.
class ScheduleWindowNote extends StatelessWidget {
  const ScheduleWindowNote({
    super.key,
    required this.open,
    required this.close,
    required this.closed,
  });

  final String open;
  final String close;
  final bool closed;

  static String? label(
    AppLocalizations l10n, {
    required String open,
    required String close,
    required bool closed,
  }) {
    if (closed) return null;
    if (open.length < 5 || close.length < 5) return null;
    final o = open.substring(0, 5);
    final c = close.substring(0, 5);
    if (o == c) return l10n.open24Hours;
    if (c.compareTo(o) < 0) return l10n.closesNextDay;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = label(
      AppLocalizations.of(context),
      open: open,
      close: close,
      closed: closed,
    );
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.brandPurple,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
