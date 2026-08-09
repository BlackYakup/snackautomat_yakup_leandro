import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_slot.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/vending_stock_sync.dart';

void main() {
  group('vending_stock_sync', () {
    test('normalizeSlotCode mappt A01 und a1 auf A1', () {
      expect(normalizeSlotCode('A1'), 'A1');
      expect(normalizeSlotCode('a01'), 'A1');
      expect(normalizeSlotCode('C4'), 'C4');
      expect(normalizeSlotCode('C04'), 'C4');
      expect(normalizeSlotCode('F10'), 'F10');
    });

    test('productMeshPrefixForSlot mappt C4 → Product_C04', () {
      expect(productMeshPrefixForSlot('C4'), 'Product_C04');
      expect(productMeshPrefixForSlot('A1'), 'Product_A01');
      expect(productMeshPrefixForSlot('B10'), 'Product_B10');
    });

    test('stockBySlotFromPlaced baut Slot→Bestand Map', () {
      final placed = [
        PlacedProduct(
          product: const Product(
            id: 1,
            name: 'A',
            priceCents: 100,
            maxCapacity: 8,
            category: ProductCategory.snacksBars,
            slotWidth: 1,
          ),
          slot: const ProductSlot(
            id: 1,
            productId: 1,
            rowLabel: 'C',
            columnNumber: 4,
            stockQuantity: 5,
            maxCapacity: 8,
          ),
        ),
        PlacedProduct(
          product: const Product(
            id: 2,
            name: 'B',
            priceCents: 100,
            maxCapacity: 8,
            category: ProductCategory.snacksBars,
            slotWidth: 1,
          ),
          slot: const ProductSlot(
            id: 2,
            productId: 2,
            rowLabel: 'A',
            columnNumber: 1,
            stockQuantity: 0,
            maxCapacity: 8,
          ),
        ),
      ];

      final map = stockBySlotFromPlaced(placed);
      expect(map['C4'], 5);
      expect(map['A1'], 0);
      // Volle Raster-Map: fehlende Slots = 0 (kein GLB-Standard).
      expect(map['B3'], 0);
      expect(map.length, 60);
    });
  });
}
