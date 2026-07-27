import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';

void main() {
  group('Product', () {
    test('Produkt mit Bestand ist nicht ausverkauft', () {
      final product = Product(
        id: 1,
        name: 'Mars',
        priceCents: 160,
        stockQuantity: 3,
        maxCapacity: 10,
        category: ProductCategory.snacksBars,
        rowLabel: 'C',
        columnNumber: 4,
        slotWidth: 1,
      );

      expect(product.isSoldOut, isFalse);
    });

    test('Produkt mit Bestand 0 ist ausverkauft', () {
      final product = Product(
        id: 1,
        name: 'Mars',
        priceCents: 160,
        stockQuantity: 0,
        maxCapacity: 10,
        category: ProductCategory.snacksBars,
        rowLabel: 'C',
        columnNumber: 4,
        slotWidth: 1,
      );

      expect(product.isSoldOut, isTrue);
    });

    test('copyWith verändert den Bestand ohne das Original zu verändern', () {
      final original = _product();

      final changed = original.copyWith(stockQuantity: 2);

      expect(original.stockQuantity, 3);
      expect(changed.stockQuantity, 2);
    });

    test('JSON-Roundtrip erhält die Produktdaten', () {
      final product = _product();

      final restored = Product.fromJson(product.toJson());

      expect(restored, product);
    });
  });
}

Product _product() {
  return const Product(
    id: 1,
    name: 'Mars',
    priceCents: 160,
    stockQuantity: 3,
    maxCapacity: 10,
    category: ProductCategory.snacksBars,
    rowLabel: 'C',
    columnNumber: 4,
    slotWidth: 1,
  );
}
