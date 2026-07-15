import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/extensions/string_extensions.dart';

void main() {
  group('StringExtensions', () {
    test('capitalize uppercases first letter', () {
      expect('hello'.capitalize, 'Hello');
    });

    test('capitalize on empty string returns empty', () {
      expect(''.capitalize, '');
    });

    test('capitalizeAll capitalizes each word', () {
      expect('hello world'.capitalizeAll, 'Hello World');
    });

    test('containsArabic detects Arabic text', () {
      expect('مرحبا'.containsArabic, isTrue);
    });

    test('containsArabic returns false for English', () {
      expect('hello'.containsArabic, isFalse);
    });

    test('truncate shortens long string', () {
      expect('hello world'.truncate(5), 'hello...');
    });

    test('truncate returns original if short enough', () {
      expect('hi'.truncate(5), 'hi');
    });

    test('isValidEmail validates correctly', () {
      expect('test@example.com'.isValidEmail, isTrue);
      expect('notanemail'.isValidEmail, isFalse);
    });

    test('isValidPhone validates correctly', () {
      expect('1234567890'.isValidPhone, isTrue);
      expect('123'.isValidPhone, isFalse);
    });
  });
}
