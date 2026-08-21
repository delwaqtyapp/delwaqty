import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_web_gate.dart';

void main() {
  group('adminWebGateStatus', () {
    test('no session resolves to notSignedIn regardless of role', () {
      expect(
        adminWebGateStatus(hasSession: false, role: 'admin'),
        AdminWebGateStatus.notSignedIn,
      );
      expect(
        adminWebGateStatus(hasSession: false),
        AdminWebGateStatus.notSignedIn,
      );
    });

    test('admin and owner roles are authorized', () {
      expect(
        adminWebGateStatus(hasSession: true, role: 'admin'),
        AdminWebGateStatus.authorized,
      );
      expect(
        adminWebGateStatus(hasSession: true, role: 'owner'),
        AdminWebGateStatus.authorized,
      );
    });

    test('non-admin roles are denied', () {
      for (final role in ['customer', 'provider', 'driver', 'merchant', null]) {
        expect(
          adminWebGateStatus(hasSession: true, role: role),
          AdminWebGateStatus.denied,
          reason: 'role=$role',
        );
      }
    });
  });

  group('AdminWebGate widget', () {
    StreamController<AuthState> authStream() =>
        StreamController<AuthState>.broadcast();

    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('shows login page when no user is signed in', (tester) async {
      final stream = authStream();
      await tester.pumpWidget(
        wrap(
          AdminWebGate(
            authStream: stream.stream,
            userIdLoader: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delwaqty Admin'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      await stream.close();
    });

    testWidgets('shows shell builder when role is admin', (tester) async {
      final stream = authStream();
      await tester.pumpWidget(
        wrap(
          AdminWebGate(
            authStream: stream.stream,
            userIdLoader: () async => 'u1',
            roleLoader: (_) async => 'admin',
            authorizedBuilder: () => const Scaffold(
              body: Text('shell'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('shell'), findsOneWidget);

      await stream.close();
    });

    testWidgets('shows shell builder when role is owner', (tester) async {
      final stream = authStream();
      await tester.pumpWidget(
        wrap(
          AdminWebGate(
            authStream: stream.stream,
            userIdLoader: () async => 'u1',
            roleLoader: (_) async => 'owner',
            authorizedBuilder: () => const Scaffold(
              body: Text('shell'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('shell'), findsOneWidget);

      await stream.close();
    });

    testWidgets('shows access denied for non-admin role', (tester) async {
      final stream = authStream();
      await tester.pumpWidget(
        wrap(
          AdminWebGate(
            authStream: stream.stream,
            userIdLoader: () async => 'u1',
            roleLoader: (_) async => 'customer',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);

      await stream.close();
    });

    testWidgets('access denied when role lookup fails', (tester) async {
      final stream = authStream();
      await tester.pumpWidget(
        wrap(
          AdminWebGate(
            authStream: stream.stream,
            userIdLoader: () async => 'u1',
            roleLoader: (_) async => throw Exception('boom'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);

      await stream.close();
    });

    testWidgets('re-resolves on auth state change', (tester) async {
      final stream = authStream();
      await tester.pumpWidget(
        wrap(
          AdminWebGate(
            authStream: stream.stream,
            userIdLoader: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);

      stream.add(const AuthState(AuthChangeEvent.signedIn, null));
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);

      await stream.close();
    });
  });
}
