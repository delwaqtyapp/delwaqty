import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:delwaqty/features/customer/restaurant/domain/entities/working_hours.dart';

bool _tzReady = false;
tz.Location _cairo() {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  return tz.getLocation('Africa/Cairo');
}

/// Schedule-only open/closed answer for one moment, mirroring
/// `public.working_hours_open_at` (migration 398) so the customer app and
/// checkout agree on what a weekly schedule means.
///
/// Storage semantics: [WorkingHours.dayOfWeek] follows the apps' convention
/// 0=Sunday..6=Saturday and records the OPENING day. A row whose close time
/// is before its open time is an overnight window: it covers
/// [open, 24:00) on its own day and [00:00, close) on the next day, so a
/// restaurant open "12:00 - 01:00" on Saturday still serves just after
/// midnight into a closed Sunday. Equal open/close times mean open 24 hours
/// on that day. Same-day windows are unchanged: [open, close).
///
/// Returns null when no schedule exists at all (the schedule does not
/// constrain the store), true/false otherwise.
///
/// [at] is an absolute instant in any timezone (typically `DateTime.now()`
/// on the device); it is converted to Africa/Cairo, the same basis the SQL
/// function uses, so a device set to a foreign timezone agrees with
/// checkout.
bool? workingHoursOpenAt(List<WorkingHours> hours, DateTime at) {
  if (hours.isEmpty) return null;
  final cairoNow = tz.TZDateTime.from(at, _cairo());

  // weekday is Mon=1..Sun=7; the apps store Sun=0..Sat=6.
  final today = cairoNow.weekday % 7;
  final yesterday = (today + 6) % 7;
  final t = cairoNow.hour * 3600 + cairoNow.minute * 60 + cairoNow.second;

  var open = false;
  for (final h in hours) {
    if (h.dayOfWeek != today && h.dayOfWeek != yesterday) continue;
    if (h.isClosed) continue;
    final openM = _minutes(h.openTime);
    final closeM = _minutes(h.closeTime);
    if (openM == null || closeM == null) continue;
    if (openM == closeM) {
      // 24h: covers the whole opening day only.
      if (h.dayOfWeek == today) open = true;
    } else if (openM < closeM) {
      // Same-day window.
      if (h.dayOfWeek == today && t >= openM && t < closeM) open = true;
    } else {
      // Overnight window: today's part after `open`, yesterday's part
      // before `close`.
      if (h.dayOfWeek == today && t >= openM) open = true;
      if (h.dayOfWeek == yesterday && t < closeM) open = true;
    }
  }
  return open;
}

/// Parses "HH:MM" or "HH:MM:SS" into seconds since midnight, so legacy
/// rows with nonzero seconds compare exactly like the SQL time values.
int? _minutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final sec = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  if (sec < 0 || sec > 59) return null;
  return h * 3600 + m * 60 + sec;
}
