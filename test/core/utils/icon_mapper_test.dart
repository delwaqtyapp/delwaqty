import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/utils/icon_mapper.dart';

void main() {
  group('categoryIconFromName', () {
    testWidgets('maps known icon name to correct IconData', (tester) async {
      expect(categoryIconFromName('shopping_cart'), Icons.shopping_cart_rounded);
      expect(categoryIconFromName('bolt'), Icons.bolt_rounded);
      expect(categoryIconFromName('restaurant'), Icons.restaurant_rounded);
      expect(categoryIconFromName('account_balance'), Icons.account_balance_rounded);
      expect(categoryIconFromName('directions_car'), Icons.directions_car_rounded);
      expect(categoryIconFromName('movie'), Icons.movie_rounded);
      expect(categoryIconFromName('home'), Icons.home_rounded);
      expect(categoryIconFromName('school'), Icons.school_rounded);
      expect(categoryIconFromName('flight'), Icons.flight_rounded);
      expect(categoryIconFromName('fitness_center'), Icons.fitness_center_rounded);
      expect(categoryIconFromName('pets'), Icons.pets_rounded);
      expect(categoryIconFromName('local_hospital'), Icons.local_hospital_rounded);
      expect(categoryIconFromName('card_giftcard'), Icons.card_giftcard_rounded);
      expect(categoryIconFromName('coffee'), Icons.coffee_rounded);
      expect(categoryIconFromName('music_note'), Icons.music_note_rounded);
      expect(categoryIconFromName('book'), Icons.book_rounded);
      expect(categoryIconFromName('child_care'), Icons.child_care_rounded);
      expect(categoryIconFromName('build'), Icons.build_rounded);
      expect(categoryIconFromName('checkroom'), Icons.checkroom_rounded);
      expect(categoryIconFromName('local_grocery_store'), Icons.local_grocery_store_rounded);
      expect(categoryIconFromName('savings'), Icons.savings_rounded);
      expect(categoryIconFromName('account_circle'), Icons.account_circle_rounded);
      expect(categoryIconFromName('category'), Icons.category_rounded);
      expect(categoryIconFromName('shopping_bag'), Icons.shopping_bag_rounded);
    });

    testWidgets('returns default icon for unknown name', (tester) async {
      expect(categoryIconFromName('unknown_icon'), Icons.category_rounded);
      expect(categoryIconFromName(''), Icons.category_rounded);
      expect(categoryIconFromName('random_name'), Icons.category_rounded);
    });
  });

  group('categoryNameFromIcon', () {
    testWidgets('maps known IconData to correct name', (tester) async {
      expect(categoryNameFromIcon(Icons.shopping_cart_rounded), 'shopping_cart');
      expect(categoryNameFromIcon(Icons.bolt_rounded), 'bolt');
      expect(categoryNameFromIcon(Icons.restaurant_rounded), 'restaurant');
      expect(categoryNameFromIcon(Icons.movie_rounded), 'movie');
      expect(categoryNameFromIcon(Icons.home_rounded), 'home');
    });

    testWidgets('returns default name for unknown icon', (tester) async {
      expect(categoryNameFromIcon(Icons.abc), 'category');
      expect(categoryNameFromIcon(Icons.access_alarm), 'category');
    });
  });

  group('availableCategoryIcons', () {
    testWidgets('returns list of all category icons', (tester) async {
      expect(availableCategoryIcons, isNotEmpty);
      expect(availableCategoryIcons.length, kCategoryIcons.length);
    });
  });
}
