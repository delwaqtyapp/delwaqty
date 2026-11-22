import 'package:delwaqty/features/customer/restaurant/domain/entities/working_hours.dart';
import 'package:delwaqty/features/customer/restaurant/domain/services/working_hours_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final created = DateTime(2026, 1, 1);

  WorkingHours row(int day, String open, String close, {bool closed = false}) {
    return WorkingHours(
      id: 'wh-$day-$open-$close',
      merchantId: 'm1',
      dayOfWeek: day,
      openTime: open,
      closeTime: close,
      isClosed: closed,
      createdAt: created,
    );
  }

  // Day convention: 0=Sunday .. 6=Saturday.
  // 2026-11-21 is a Saturday, 2026-11-22 Sunday, 2026-11-23 Monday,
  // 2026-11-24 Tuesday, 2026-11-25 Wednesday, 2026-11-26 Thursday.
  final schedule = [
    row(6, '12:00', '01:00'), // Saturday, overnight past midnight
    row(0, '09:00', '23:00', closed: true), // Sunday closed
    row(1, '09:00', '23:00'), // Monday same-day
    row(2, '00:00', '00:00'), // Tuesday open 24 hours
    row(3, '23:30', '00:00'), // Wednesday, overnight ending at midnight
  ];

  group('workingHoursOpenAt overnight windows', () {
    test('open during the evening part of an overnight window', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 21, 13, 0)),
        isTrue,
      );
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 21, 23, 59)),
        isTrue,
      );
    });

    test('closed before an overnight window opens', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 21, 11, 59)),
        isFalse,
      );
    });

    test('overnight window spills past midnight into a closed day', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 22, 0, 30)),
        isTrue,
        reason: 'Saturday 12:00-01:00 still serves at 00:30 on Sunday',
      );
    });

    test('close time is exclusive at the day rollover', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 22, 1, 0)),
        isFalse,
      );
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 22, 2, 0)),
        isFalse,
      );
    });

    test('closed day stays closed outside the overnight spill', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 22, 12, 0)),
        isFalse,
      );
    });
  });

  group('workingHoursOpenAt same-day windows stay identical', () {
    test('boundaries are inclusive at open, exclusive at close', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 23, 8, 59)),
        isFalse,
      );
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 23, 9, 0)),
        isTrue,
      );
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 23, 22, 59)),
        isTrue,
      );
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 23, 23, 0)),
        isFalse,
      );
    });

    test('a same-day window never spills into the next day', () {
      final sameDayOnly = [row(2, '09:00', '23:00')]; // Tuesday
      expect(
        workingHoursOpenAt(sameDayOnly, DateTime(2026, 11, 25, 1, 0)),
        isFalse,
        reason: 'Tuesday 09:00-23:00 must not leak into Wednesday',
      );
    });
  });

  group('workingHoursOpenAt 24h and midnight edges', () {
    test('open == close means open 24 hours on that day', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 24, 0, 0)),
        isTrue,
      );
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 24, 15, 0)),
        isTrue,
      );
    });

    test('a 24h day ends at midnight and does not spill', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 25, 3, 0)),
        isFalse,
      );
    });

    test('a window closing at 00:00 ends exactly at midnight', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 25, 23, 45)),
        isTrue,
      );
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 26, 0, 0)),
        isFalse,
      );
    });
  });

  group('workingHoursOpenAt schedule presence', () {
    test('no rows means the schedule does not constrain the store', () {
      expect(
        workingHoursOpenAt(const [], DateTime(2026, 11, 23, 12, 0)),
        isNull,
      );
    });

    test('a day with no row is closed when a schedule exists', () {
      expect(
        workingHoursOpenAt(schedule, DateTime(2026, 11, 27, 12, 0)),
        isFalse,
        reason: 'Friday has no row at all',
      );
    });

    test('accepts HH:MM:SS time strings from the database', () {
      final secondsSchedule = [row(1, '09:00:00', '23:00:00')];
      expect(
        workingHoursOpenAt(secondsSchedule, DateTime(2026, 11, 23, 10, 0)),
        isTrue,
      );
    });
  });
}
