import 'dart:async';

import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/working_hours.dart';
import 'package:delwaqty/features/customer/restaurant/domain/services/working_hours_status.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Open/closed badge combining the store's manual flag with its weekly
/// schedule (overnight and 24h windows included), recomputed in
/// Africa/Cairo inside [workingHoursOpenAt].
///
/// The badge re-evaluates on a light periodic tick and whenever the app
/// resumes, so a page left mounted across a close/open boundary does not
/// stay stale.
class OpenStatusBadge extends StatefulWidget {
  const OpenStatusBadge({
    super.key,
    required this.manualOpen,
    required this.hours,
    this.clock,
    this.tick,
  });

  /// The store's manual merchants.is_open flag.
  final bool manualOpen;

  /// The weekly schedule; an empty list means unconstrained.
  final List<WorkingHours> hours;

  /// Test hook: instant source. Defaults to DateTime.now.
  final DateTime Function()? clock;

  /// Test hook: re-evaluation period. Defaults to one minute.
  final Duration? tick;

  @override
  State<OpenStatusBadge> createState() => _OpenStatusBadgeState();
}

class _OpenStatusBadgeState extends State<OpenStatusBadge>
    with WidgetsBindingObserver {
  Timer? _timer;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.tick ?? const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheduleOpen = workingHoursOpenAt(widget.hours, _now());
    final effectiveOpen = widget.manualOpen && (scheduleOpen ?? true);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveOpen
            ? AppColors.successLight.withValues(alpha: 0.1)
            : AppColors.errorLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        effectiveOpen ? l10n.open : l10n.closed,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: effectiveOpen ? AppColors.successLight : AppColors.errorLight,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
