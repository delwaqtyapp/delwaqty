extension StringExtensions on String {
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String get capitalizeAll =>
      split(' ').map((word) => word.capitalize).join(' ');

  bool get containsArabic {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(this);
  }

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$suffix';
  }

  bool get isValidEmail =>
      RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$').hasMatch(this);

  bool get isValidPhone =>
      RegExp(r'^[+]?[0-9]{10,15}$').hasMatch(this);
}
