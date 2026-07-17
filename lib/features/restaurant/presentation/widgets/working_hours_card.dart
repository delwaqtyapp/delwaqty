import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/restaurant/domain/entities/working_hours.dart';

class WorkingHoursCard extends StatelessWidget {
  const WorkingHoursCard({super.key, required this.hours});

  final List<WorkingHours> hours;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = DateTime.now().weekday;
    final sortedHours = List<WorkingHours>.from(hours)..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    final dayNames = [
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
      l10n.sunday,
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(
            Icons.schedule_outlined,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          title: Text(
            l10n.workingHours,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          initiallyExpanded: false,
          children: sortedHours.map((hour) {
            final isToday = hour.dayOfWeek == today;
            final dayName = hour.dayOfWeek >= 1 && hour.dayOfWeek <= 7
                ? dayNames[hour.dayOfWeek - 1]
                : 'Day ${hour.dayOfWeek}';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      dayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: hour.isClosed
                        ? Text(
                            l10n.closed,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          )
                        : Text(
                            '${hour.openTime} - ${hour.closeTime}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? theme.colorScheme.primary : null,
                            ),
                          ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.today,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
