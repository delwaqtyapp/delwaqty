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

  // The helper converts any instant to Africa/Cairo, so every expectation
  // below is written as a UTC instant and is independent of the test
  // runner's own timezone. Cairo is UTC+2 in late November 2026 (DST ended
  // 2026-10-29) and UTC+3 during DST. Dates: 2026-11-21 Sat, 22 Sun,
  // 23 Mon, 24 Tue, 25 Wed, 26 Thu, 27 Fri.
  DateTime nov(int day, int hour, [int minute = 0]) =>
      DateTime.utc(2026, 11, day, hour - 2, minute); // Cairo local -> UTC

  final schedule = [
    row(6, '12:00', '01:00'), // Saturday, overnight past midnight
    row(0, '09:00', '23:00', closed: true), // Sunday closed
    row(1, '09:00', '23:00'), // Monday same-day
    row(2, '00:00', '00:00'), // Tuesday open 24 hours
    row(3, '23:30', '00:00'), // Wednesday, overnight ending at midnight
  ];

  group('overnight windows', () {
    test('open during the evening part of an overnight window', () {
      expect(workingHoursOpenAt(schedule, nov(21, 13)), isTrue);
      expect(workingHoursOpenAt(schedule, nov(21, 23, 59)), isTrue);
    });

    test('closed before an overnight window opens', () {
      expect(workingHoursOpenAt(schedule, nov(21, 11, 59)), isFalse);
    });

    test('overnight window spills past midnight into a closed day', () {
      expect(
        workingHoursOpenAt(schedule, nov(22, 0, 30)),
        isTrue,
        reason: 'Saturday 12:00-01:00 still serves at 00:30 on Sunday',
      );
    });

    test('close time is exclusive at the day rollover', () {
      expect(workingHoursOpenAt(schedule, nov(22, 1)), isFalse);
      expect(workingHoursOpenAt(schedule, nov(22, 2)), isFalse);
    });

    test('closed day stays closed outside the overnight spill', () {
      expect(workingHoursOpenAt(schedule, nov(22, 12)), isFalse);
    });
  });

  group('same-day windows stay identical', () {
    test('boundaries are inclusive at open, exclusive at close', () {
      expect(workingHoursOpenAt(schedule, nov(23, 8, 59)), isFalse);
      expect(workingHoursOpenAt(schedule, nov(23, 9)), isTrue);
      expect(workingHoursOpenAt(schedule, nov(23, 22, 59)), isTrue);
      expect(workingHoursOpenAt(schedule, nov(23, 23)), isFalse);
    });

    test('a same-day window never spills into the next day', () {
      final sameDayOnly = [row(2, '09:00', '23:00')]; // Tuesday
      expect(
        workingHoursOpenAt(sameDayOnly, nov(25, 1)),
        isFalse,
        reason: 'Tuesday 09:00-23:00 must not leak into Wednesday',
      );
    });
  });

  group('24h and midnight edges', () {
    test('open == close means open 24 hours on that day', () {
      expect(workingHoursOpenAt(schedule, nov(24, 0)), isTrue);
      expect(workingHoursOpenAt(schedule, nov(24, 15)), isTrue);
    });

    test('equal non-midnight times also mean 24 hours', () {
      final s = [row(1, '09:00', '09:00')]; // Monday
      expect(workingHoursOpenAt(s, nov(23, 0)), isTrue);
      expect(workingHoursOpenAt(s, nov(23, 9)), isTrue);
      expect(workingHoursOpenAt(s, nov(23, 23, 59)), isTrue);
      expect(
        workingHoursOpenAt(s, nov(24, 0, 1)),
        isFalse,
        reason: 'Monday 24h ends at midnight, Tuesday has no row',
      );
    });

    test('a 24h day ends at midnight and does not spill', () {
      expect(workingHoursOpenAt(schedule, nov(25, 3)), isFalse);
    });

    test('a window closing at 00:00 ends exactly at midnight', () {
      expect(workingHoursOpenAt(schedule, nov(25, 23, 45)), isTrue);
      expect(workingHoursOpenAt(schedule, nov(26, 0)), isFalse);
    });
  });

  group('device timezone independence (Africa/Cairo basis)', () {
    // Monday 09:00-23:00 Cairo. A device set to UTC sees 06:59/07:00 UTC at
    // the Cairo 08:59/09:00 boundary; the answer must follow Cairo, not the
    // device.
    final monday = [row(1, '09:00', '23:00')];
    test('UTC device before Cairo opening is closed', () {
      expect(
        workingHoursOpenAt(monday, DateTime.utc(2026, 11, 23, 6, 59)),
        isFalse,
      );
    });
    test('UTC device at Cairo opening is open', () {
      expect(
        workingHoursOpenAt(monday, DateTime.utc(2026, 11, 23, 7, 0)),
        isTrue,
      );
    });
  });

  group('Egypt DST transitions', () {
    // DST 2026: starts last Friday of April (2026-04-24) at 00:00 local
    // (+2 -> +3, i.e. 2026-04-23 22:00 UTC); ends last Thursday of October
    // (2026-10-29) at 24:00 local (+3 -> +2, i.e. 2026-10-29 21:00 UTC).
    test('spring forward: 2026-04-23 23:00 UTC is 02:00 Cairo (+3)', () {
      // Thursday (4) overnight 22:00-02:00, close exclusive.
      final s = [row(4, '22:00', '02:00')];
      expect(
        workingHoursOpenAt(s, DateTime.utc(2026, 4, 23, 22, 59)),
        isTrue,
        reason: '00:59 Cairo Friday, still inside Thursday overnight',
      );
      expect(
        workingHoursOpenAt(s, DateTime.utc(2026, 4, 23, 23, 0)),
        isFalse,
        reason: '02:00 Cairo Friday, the window just closed',
      );
    });

    test('fall back: 2026-10-29 21:00 UTC is 23:00 Cairo (+2)', () {
      // Thursday (4) same-day 23:00-23:59.
      final s = [row(4, '23:00', '23:59')];
      expect(
        workingHoursOpenAt(s, DateTime.utc(2026, 10, 29, 20, 59)),
        isFalse,
        reason: '23:59 Cairo Thursday, close is exclusive',
      );
      expect(
        workingHoursOpenAt(s, DateTime.utc(2026, 10, 29, 21, 0)),
        isTrue,
        reason: '23:00 Cairo Thursday after the fallback',
      );
    });
  });

  group('legacy HH:MM:SS with nonzero seconds', () {
    final s = [row(1, '09:00:30', '23:00:30')]; // Monday
    test('seconds participate like SQL time comparison', () {
      expect(
        workingHoursOpenAt(s, DateTime.utc(2026, 11, 23, 7, 0, 15)),
        isFalse,
        reason: '09:00:15 Cairo is before 09:00:30',
      );
      expect(
        workingHoursOpenAt(s, DateTime.utc(2026, 11, 23, 7, 0, 45)),
        isTrue,
      );
      expect(
        workingHoursOpenAt(s, DateTime.utc(2026, 11, 23, 21, 0, 45)),
        isFalse,
        reason: '23:00:45 Cairo is past 23:00:30',
      );
    });
  });

  group('schedule presence', () {
    test('no rows means the schedule does not constrain the store', () {
      expect(workingHoursOpenAt(const [], nov(23, 12)), isNull);
    });

    test('a day with no row is closed when a schedule exists', () {
      expect(
        workingHoursOpenAt(schedule, nov(27, 12)),
        isFalse,
        reason: 'Friday has no row at all',
      );
    });

    test('accepts HH:MM:SS time strings from the database', () {
      final secondsSchedule = [row(1, '09:00:00', '23:00:00')];
      expect(workingHoursOpenAt(secondsSchedule, nov(23, 10)), isTrue);
    });
  });
}
