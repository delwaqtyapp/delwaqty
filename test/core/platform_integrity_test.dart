import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/core/router/post_auth_route.dart';
import 'package:delwaqty/core/utils/avatar_initial.dart';

void main() {
  group('postAuthRoute', () {
    // The welcome / login / register / device-unlock screens are shared by
    // all four flavors but hard-coded '/home', which only the customer
    // registry registers. Driver and provider therefore landed on the
    // router's unrecoverable "page not found" screen.
    test('resolves the flavor landing route, never the customer-only /home', () {
      expect(postAuthRoute(AppFlavor.customer), '/home');
      expect(postAuthRoute(AppFlavor.admin), '/admin');
      expect(postAuthRoute(AppFlavor.driver), '/driver');
      expect(postAuthRoute(AppFlavor.provider), '/merchant-dashboard');
    });

    test('driver and provider never receive the customer-only /home route', () {
      expect(postAuthRoute(AppFlavor.driver), isNot('/home'));
      expect(postAuthRoute(AppFlavor.provider), isNot('/home'));
    });
  });

  group('safeInitial', () {
    // `(name ?? email ?? username)?.substring(0, 1)` throws a RangeError on
    // an EMPTY string, which crashed the members list, the member drawer,
    // the member detail header and the support-chat picker.
    test('never throws on null', () {
      expect(safeInitial(null), '?');
    });

    test('never throws on an empty or blank string', () {
      expect(safeInitial(''), '?');
      expect(safeInitial('   '), '?');
    });

    test('returns the upper-cased first character', () {
      expect(safeInitial('ahmed'), 'A');
      expect(safeInitial('  mostafa'), 'M');
    });

    test('handles a single character and non-latin scripts', () {
      expect(safeInitial('م'), 'م');
      expect(safeInitial('Z'), 'Z');
    });

    test('accepts a custom fallback', () {
      expect(safeInitial('', fallback: 'U'), 'U');
    });
  });

  group('safeInitialFrom', () {
    test('picks the first non-empty field', () {
      expect(safeInitialFrom([null, 'ahmed', 'x']), 'A');
    });

    test('skips empty and blank fields', () {
      expect(safeInitialFrom(['', '   ', 'mostafa']), 'M');
    });

    test('returns the fallback when nothing is usable', () {
      expect(safeInitialFrom([null, '', '  ']), '?');
    });
  });
}