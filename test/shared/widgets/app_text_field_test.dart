import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/app_text_field.dart';

void main() {
  Widget buildTestWidget({
    String? label,
    String? hint,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Form(
          child: AppTextField(
            label: label,
            hint: hint,
            obscureText: obscureText,
            validator: validator,
          ),
        ),
      ),
    );
  }

  group('AppTextField', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Email'));
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('renders hint text', (tester) async {
      await tester.pumpWidget(buildTestWidget(hint: 'Enter your email'));
      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('accepts text input', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('obscures text when obscureText is true', (tester) async {
      await tester.pumpWidget(buildTestWidget(obscureText: true));
      final textField = tester.widget<AppTextField>(
        find.byType(AppTextField),
      );
      expect(textField.obscureText, isTrue);
    });

    testWidgets('does not obscure text by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      final textField = tester.widget<AppTextField>(
        find.byType(AppTextField),
      );
      expect(textField.obscureText, isFalse);
    });

    testWidgets('shows validation error on empty input', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '');
      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('does not show error for valid input', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'valid input');
      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsNothing);
    });

    testWidgets('can be disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Form(
              child: AppTextField(
                enabled: false,
                label: 'Disabled',
              ),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );
      expect(textField.enabled, isFalse);
    });
  });
}
