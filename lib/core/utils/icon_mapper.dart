import 'package:flutter/material.dart';

const Map<String, IconData> kCategoryIcons = {
  'shopping_cart': Icons.shopping_cart_rounded,
  'shopping_bag': Icons.shopping_bag_rounded,
  'bolt': Icons.bolt_rounded,
  'restaurant': Icons.restaurant_rounded,
  'account_balance': Icons.account_balance_rounded,
  'directions_car': Icons.directions_car_rounded,
  'movie': Icons.movie_rounded,
  'home': Icons.home_rounded,
  'school': Icons.school_rounded,
  'flight': Icons.flight_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'pets': Icons.pets_rounded,
  'local_hospital': Icons.local_hospital_rounded,
  'card_giftcard': Icons.card_giftcard_rounded,
  'coffee': Icons.coffee_rounded,
  'music_note': Icons.music_note_rounded,
  'book': Icons.book_rounded,
  'child_care': Icons.child_care_rounded,
  'build': Icons.build_rounded,
  'checkroom': Icons.checkroom_rounded,
  'local_grocery_store': Icons.local_grocery_store_rounded,
  'savings': Icons.savings_rounded,
  'account_circle': Icons.account_circle_rounded,
  'category': Icons.category_rounded,
};

List<IconData> get availableCategoryIcons => kCategoryIcons.values.toList();

IconData categoryIconFromName(String name) {
  return kCategoryIcons[name] ?? Icons.category_rounded;
}

String categoryNameFromIcon(IconData icon) {
  for (final entry in kCategoryIcons.entries) {
    if (entry.value == icon) return entry.key;
  }
  return 'category';
}
