import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/extensions/date_extensions.dart';

void main() {
  group('DateTimeExtensions', () {
    test('isToday returns true for current date', () {
      expect(DateTime.now().isToday, isTrue);
    });

    test('isToday returns false for yesterday', () {
      expect(
        DateTime.now().subtract(const Duration(days: 1)).isToday,
        isFalse,
      );
    });

    test('isYesterday returns true for yesterday', () {
      expect(
        DateTime.now().subtract(const Duration(days: 1)).isYesterday,
        isTrue,
      );
    });

    test('isYesterday returns false for today', () {
      expect(DateTime.now().isYesterday, isFalse);
    });

    test('timeAgo returns Just now for recent time', () {
      expect(DateTime.now().timeAgo(), 'Just now');
    });

    test('timeAgo returns minutes ago', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 5));
      expect(dt.timeAgo(), '5m ago');
    });

    test('timeAgo returns hours ago', () {
      final dt = DateTime.now().subtract(const Duration(hours: 3));
      expect(dt.timeAgo(), '3h ago');
    });

    test('timeAgo returns days ago', () {
      final dt = DateTime.now().subtract(const Duration(days: 2));
      expect(dt.timeAgo(), '2d ago');
    });
  });
}
