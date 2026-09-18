abstract final class AppValidators {
  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? '$fieldName is required' : 'This field is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Accepts an email OR a username (3–32 chars: letters, digits, underscore,
  /// dot — no spaces). Usernames are resolved to their auth email at sign-in.
  static String? loginIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or username is required';
    }
    final v = value.trim();
    if (v.contains('@')) return email(value);
    final usernameRegex = RegExp(r'^[\w.]{3,32}$');
    if (!usernameRegex.hasMatch(v)) {
      return 'Enter a valid email or username';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^[+]?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? minLength(String? value, int min, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? '$fieldName is required' : 'This field is required';
    }
    if (value.trim().length < min) {
      return fieldName != null
          ? '$fieldName must be at least $min characters'
          : 'Must be at least $min characters';
    }
    return null;
  }

  static String? maxLength(String? value, int max, [String? fieldName]) {
    if (value != null && value.trim().length > max) {
      return fieldName != null
          ? '$fieldName must be at most $max characters'
          : 'Must be at most $max characters';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String passwordValue) {
    final error = AppValidators.password(value);
    if (error != null) return error;
    if (value != passwordValue) {
      return 'Passwords do not match';
    }
    return null;
  }
}
