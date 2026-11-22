import 'package:delwaqty/features/provider/merchant/domain/pos_product_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final products = <Map<String, dynamic>>[
    {'id': 'p1', 'name': 'شاي ليبتون', 'barcode': '6223000111'},
    {'id': 'p2', 'name': 'Rice', 'name_ar': 'أرز', 'barcode': null},
    {'id': 'p3', 'name': 'Oil', 'barcode': '  '},
    {'id': 'p4', 'name': 'Sugar', 'barcode': '6223000444'},
  ];

  group('normalizeBarcode', () {
    test('trims and tolerates null', () {
      expect(normalizeBarcode('  6223000111 '), '6223000111');
      expect(normalizeBarcode(null), '');
      expect(normalizeBarcode('   '), '');
    });
  });

  group('findProductByBarcode', () {
    test('finds an exact match ignoring scanner whitespace', () {
      expect(findProductByBarcode(products, '6223000111')?['id'], 'p1');
      expect(findProductByBarcode(products, ' 6223000111\n')?['id'], 'p1');
    });

    test('returns null for empty or unknown barcodes', () {
      expect(findProductByBarcode(products, ''), isNull);
      expect(findProductByBarcode(products, '999999'), isNull);
    });

    test('never matches null/blank product barcodes', () {
      // A blank search must not "match" products that carry no barcode.
      expect(findProductByBarcode(products, ' '), isNull);
    });
  });

  group('barcodeTakenByOtherProduct', () {
    test('true when another product owns the barcode', () {
      expect(barcodeTakenByOtherProduct(products, '6223000111', 'p4'), isTrue);
    });

    test('false for the product currently being edited', () {
      expect(barcodeTakenByOtherProduct(products, '6223000111', 'p1'), isFalse);
    });

    test('false when the barcode is free', () {
      expect(barcodeTakenByOtherProduct(products, '0000', null), isFalse);
    });
  });

  group('filterProductsForPos', () {
    test('blank query returns everything', () {
      expect(filterProductsForPos(products, ' ').length, products.length);
    });

    test('matches name, Arabic name and barcode case-insensitively', () {
      expect(filterProductsForPos(products, 'rice').single['id'], 'p2');
      expect(filterProductsForPos(products, 'أرز').single['id'], 'p2');
      expect(filterProductsForPos(products, 'ليبتون').single['id'], 'p1');
      expect(filterProductsForPos(products, '6223000444').single['id'], 'p4');
    });

    test('no match returns empty, not everything', () {
      expect(filterProductsForPos(products, 'xyz-not-there'), isEmpty);
    });
  });
}
