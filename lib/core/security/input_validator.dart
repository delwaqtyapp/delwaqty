/// Input validation for the Delwaqty platform.
///
/// Provides field-level validation and sanitization helpers to protect
/// against injection attacks and malformed user input.
library;

/// The result of a single validation check.
class ValidationResult {
  /// Creates a valid [ValidationResult].
  const ValidationResult.valid() : isValid = true, errors = const [];

  /// Creates an invalid [ValidationResult] with the given [errors].
  const ValidationResult.invalid(List<String> errors)
    : isValid = false,
      this.errors = errors;

  /// Whether the validated input is valid.
  final bool isValid;

  /// Human-readable error messages (empty when valid).
  final List<String> errors;

  @override
  String toString() => isValid ? 'valid' : 'invalid(${errors.join(', ')})';
}

/// Abstract interface for input validation.
abstract class InputValidator {
  /// Validates an email address.
  ValidationResult validateEmail(String email);

  /// Validates a password against platform policy.
  ValidationResult validatePassword(String password);

  /// Validates a phone number.
  ValidationResult validatePhone(String phone);

  /// Validates a display name.
  ValidationResult validateName(String name);

  /// Validates a postal address.
  ValidationResult validateAddress(String address);

  /// Strips HTML tags from the input.
  String sanitizeHtml(String input);

  /// Escapes SQL-special characters in the input.
  String sanitizeSql(String input);
}

/// Default implementation with common validation rules.
class DefaultInputValidator extends InputValidator {
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static final _phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');

  static final _htmlTagRegex = RegExp(r'<[^>]*>');

  @override
  ValidationResult validateEmail(String email) {
    final errors = <String>[];
    if (email.isEmpty) {
      errors.add('Email is required');
    } else if (!_emailRegex.hasMatch(email)) {
      errors.add('Email format is invalid');
    }
    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  @override
  ValidationResult validatePassword(String password) {
    final errors = <String>[];
    if (password.isEmpty) {
      errors.add('Password is required');
    } else {
      if (password.length < 8)
        errors.add('Password must be at least 8 characters');
      if (!RegExp(r'[A-Z]').hasMatch(password)) {
        errors.add('Password must contain at least one uppercase letter');
      }
      if (!RegExp(r'[a-z]').hasMatch(password)) {
        errors.add('Password must contain at least one lowercase letter');
      }
      if (!RegExp(r'[0-9]').hasMatch(password)) {
        errors.add('Password must contain at least one digit');
      }
    }
    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  @override
  ValidationResult validatePhone(String phone) {
    final errors = <String>[];
    if (phone.isEmpty) {
      errors.add('Phone number is required');
    } else if (!_phoneRegex.hasMatch(
      phone.replaceAll(RegExp(r'[\s\-()]'), ''),
    )) {
      errors.add('Phone number format is invalid');
    }
    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  @override
  ValidationResult validateName(String name) {
    final errors = <String>[];
    if (name.trim().isEmpty) {
      errors.add('Name is required');
    } else if (name.trim().length < 2) {
      errors.add('Name must be at least 2 characters');
    } else if (name.trim().length > 100) {
      errors.add('Name must be at most 100 characters');
    }
    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  @override
  ValidationResult validateAddress(String address) {
    final errors = <String>[];
    if (address.trim().isEmpty) {
      errors.add('Address is required');
    } else if (address.trim().length < 5) {
      errors.add('Address must be at least 5 characters');
    } else if (address.trim().length > 500) {
      errors.add('Address must be at most 500 characters');
    }
    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  @override
  String sanitizeHtml(String input) {
    return input.replaceAll(_htmlTagRegex, '');
  }

  @override
  String sanitizeSql(String input) {
    return input
        .replaceAll("'", "''")
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '')
        .replaceAll('--', '')
        .replaceAll('/*', '')
        .replaceAll('*/', '');
  }
}

/// No-op validator that accepts everything.
class NoOpInputValidator extends InputValidator {
  @override
  ValidationResult validateEmail(String email) => ValidationResult.valid();

  @override
  ValidationResult validatePassword(String password) =>
      ValidationResult.valid();

  @override
  ValidationResult validatePhone(String phone) => ValidationResult.valid();

  @override
  ValidationResult validateName(String name) => ValidationResult.valid();

  @override
  ValidationResult validateAddress(String address) => ValidationResult.valid();

  @override
  String sanitizeHtml(String input) => input;

  @override
  String sanitizeSql(String input) => input;
}
