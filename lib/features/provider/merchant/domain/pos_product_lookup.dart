/// Pure POS lookup helpers (no I/O) shared by the cashier page and the
/// product form. Unit-tested; keep free of Flutter/Supabase imports.

/// Normalizes a typed or scanned barcode. THE one rule, shared with the
/// server (products_barcode_canonicalize in migration 400): trim ASCII
/// space, tab, CR and LF from both ends; empty becomes empty. Wider
/// Unicode whitespace is deliberately NOT trimmed so client lookup and the
/// unique index can never disagree.
/// Returns an empty string for null/blank input.
String normalizeBarcode(String? raw) =>
    (raw ?? '').replaceAll(RegExp(r'^[ \t\r\n]+|[ \t\r\n]+$'), '');

/// Exact barcode match over a merchant's product rows (PostgREST maps).
/// Returns the first product whose normalized barcode equals [barcode],
/// or null when nothing matches. Scan-to-add and typed-barcode lookup both
/// rely on a barcode identifying at most one product per store; the
/// products_merchant_barcode_uq index (migration 400) enforces that
/// server-side.
Map<String, dynamic>? findProductByBarcode(
  List<Map<String, dynamic>> products,
  String barcode,
) {
  final target = normalizeBarcode(barcode);
  if (target.isEmpty) return null;
  for (final product in products) {
    if (normalizeBarcode(product['barcode'] as String?) == target) {
      return product;
    }
  }
  return null;
}

/// True when [barcode] is already used by a product other than
/// [excludeProductId] (the product being edited). Used by the product form's
/// client-side uniqueness check before saving; the server index stays the
/// enforcement of last resort.
bool barcodeTakenByOtherProduct(
  List<Map<String, dynamic>> products,
  String barcode,
  String? excludeProductId,
) {
  final found = findProductByBarcode(products, barcode);
  if (found == null) return false;
  return found['id']?.toString() != excludeProductId;
}

/// Case-insensitive substring filter for the POS search field. Matches the
/// product name, Arabic name, category and barcode so the same box serves
/// typed barcodes and name search.
List<Map<String, dynamic>> filterProductsForPos(
  List<Map<String, dynamic>> products,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return products;
  return products.where((p) {
    final haystack = [
      p['name'],
      p['name_ar'],
      p['category'],
      p['barcode'],
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
}
