import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_slot.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';

void main() {
  group('Product / PlacedProduct', () {
    test('Katalog-Produkt hat slotWidth ohne Slot-Lage', () {
      final product = _sampleProduct();
      expect(product.slotWidth, 1);
      expect(product.priceCents, 160);
    });

    test('PlacedProduct SoldOut aus Slot-Bestand', () {
      final placed = PlacedProduct(
        product: _sampleProduct(),
        slot: const ProductSlot(
          productId: 1,
          rowLabel: 'C',
          columnNumber: 4,
          stockQuantity: 0,
          maxCapacity: 10,
        ),
      );
      expect(placed.isSoldOut, isTrue);
    });

    test('copyWithStock ändert nur Slot', () {
      final original = PlacedProduct(
        product: _sampleProduct(),
        slot: const ProductSlot(
          productId: 1,
          rowLabel: 'C',
          columnNumber: 4,
          stockQuantity: 3,
          maxCapacity: 10,
        ),
      );
      final changed = original.copyWithStock(2);
      expect(original.stockQuantity, 3);
      expect(changed.stockQuantity, 2);
      expect(changed.product.name, original.product.name);
    });
  });
}

Product _sampleProduct() {
  return const Product(
    id: 1,
    name: 'Test',
    priceCents: 160,
    maxCapacity: 10,
    category: ProductCategory.snacksBars,
    slotWidth: 1,
  );
}
