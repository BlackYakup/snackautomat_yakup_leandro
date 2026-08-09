import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_slot.dart';
import 'package:sqflite/sqflite.dart';

class ProductRepository {
  const ProductRepository(this.db);

  final Database db;

  Future<List<Product>> getProducts() async {
    final rows = await db.query('product', orderBy: 'name ASC');
    return rows
        .map((row) => Product.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<ProductSlot>> getSlots() async {
    final rows = await db.query(
      'product_slot',
      orderBy: 'row_label ASC, column_number ASC',
    );
    return rows
        .map((row) => ProductSlot.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<PlacedProduct>> getPlacedProducts() async {
    final products = await getProducts();
    final byId = {for (final p in products) if (p.id != null) p.id!: p};
    final slots = await getSlots();
    final placed = <PlacedProduct>[];
    for (final slot in slots) {
      final product = byId[slot.productId];
      if (product == null) continue;
      placed.add(PlacedProduct(product: product, slot: slot));
    }
    return placed;
  }

  Future<int> saveProduct(Product product) async {
    _validateCatalogProduct(product);

    final values = Map<String, Object?>.from(product.toJson())..remove('id');
    values['image_path'] = product.imagePath;
    values['model_path'] = product.modelPath;
    values['model_part'] = product.modelPart;
    values['icon_key'] = product.iconKey;

    if (product.id == null) {
      return db.insert('product', values);
    }

    await db.update(
      'product',
      values,
      where: 'id = ?',
      whereArgs: [product.id],
    );
    return product.id!;
  }

  Future<ProductSlot> assignProductToSlot({
    required Product product,
    required String rowLabel,
    required int columnNumber,
    required int stockQuantity,
    int? maxCapacity,
    int? existingSlotId,
  }) async {
    final productId = product.id;
    if (productId == null) {
      throw ArgumentError('Produkt muss gespeichert sein.');
    }

    final capacity = maxCapacity ?? product.maxCapacity;
    final slot = ProductSlot(
      id: existingSlotId,
      productId: productId,
      rowLabel: rowLabel.toUpperCase(),
      columnNumber: columnNumber,
      stockQuantity: stockQuantity,
      maxCapacity: capacity,
    );

    _validateSlotPlacement(product: product, slot: slot);

    return db.transaction((txn) async {
      final hasOverlap = await _hasOverlappingSlot(
        txn,
        slot: slot,
        slotWidth: product.slotWidth,
      );
      if (hasOverlap) {
        throw StateError('Slot ist bereits belegt.');
      }

      final values = Map<String, Object?>.from(slot.toJson())..remove('id');
      values['row_label'] = slot.rowLabel.toUpperCase();

      if (existingSlotId == null) {
        final id = await txn.insert('product_slot', values);
        return slot.copyWith(id: id);
      }

      final updated = await txn.update(
        'product_slot',
        values,
        where: 'id = ?',
        whereArgs: [existingSlotId],
      );
      if (updated == 0) {
        final id = await txn.insert('product_slot', values);
        return slot.copyWith(id: id);
      }
      return slot;
    });
  }

  Future<void> clearSlot(int slotId) async {
    await db.delete('product_slot', where: 'id = ?', whereArgs: [slotId]);
  }

  Future<void> deleteProduct(int productId) async {
    await db.transaction((txn) async {
      await txn.delete(
        'product_slot',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      await txn.delete('product', where: 'id = ?', whereArgs: [productId]);
    });
  }

  Future<void> updateSlotStock({
    required int slotId,
    required int stockQuantity,
  }) async {
    await db.update(
      'product_slot',
      {'stock_quantity': stockQuantity},
      where: 'id = ?',
      whereArgs: [slotId],
    );
  }

  /// Speichert Katalogprodukt und Slot-Belegung zusammen (UI-Kompatibilität).
  Future<PlacedProduct> saveProductAtSlot(PlacedProduct placed) async {
    final productId = await saveProduct(placed.product);
    final product = placed.product.copyWith(id: productId);

    final existingSlots = await getSlots();
    final matchingSlot = existingSlots.cast<ProductSlot?>().firstWhere(
      (slot) =>
          slot!.id == placed.slotId ||
          (slot.productId == productId &&
              slot.rowLabel.toUpperCase() == placed.rowLabel.toUpperCase() &&
              slot.columnNumber == placed.columnNumber),
      orElse: () => null,
    );

    final slot = await assignProductToSlot(
      product: product,
      rowLabel: placed.rowLabel,
      columnNumber: placed.columnNumber,
      stockQuantity: placed.stockQuantity,
      maxCapacity: placed.maxCapacity,
      existingSlotId: matchingSlot?.id ?? placed.slotId,
    );

    return PlacedProduct(product: product, slot: slot);
  }

  Future<void> updateStockQuantity({
    required int productId,
    required int stockQuantity,
    int? slotId,
    String? rowLabel,
    int? columnNumber,
  }) async {
    if (slotId != null) {
      await updateSlotStock(slotId: slotId, stockQuantity: stockQuantity);
      return;
    }

    final slots = await getSlots();
    final match = slots.cast<ProductSlot?>().firstWhere(
      (slot) {
        if (slot!.productId != productId) return false;
        if (rowLabel != null &&
            slot.rowLabel.toUpperCase() != rowLabel.toUpperCase()) {
          return false;
        }
        if (columnNumber != null && slot.columnNumber != columnNumber) {
          return false;
        }
        return true;
      },
      orElse: () => null,
    );

    if (match == null) {
      throw StateError('Kein Slot für Produkt $productId gefunden.');
    }

    await updateSlotStock(slotId: match.id!, stockQuantity: stockQuantity);
  }

  void _validateCatalogProduct(Product product) {
    if (product.slotWidth != 1 && product.slotWidth != 2) {
      throw ArgumentError('slotWidth muss 1 oder 2 sein.');
    }
    if (product.maxCapacity < 1) {
      throw ArgumentError('maxCapacity muss mindestens 1 sein.');
    }
  }

  void _validateSlotPlacement({
    required Product product,
    required ProductSlot slot,
  }) {
    final rowLabel = slot.rowLabel.toUpperCase();

    if (!const ['A', 'B', 'C', 'D', 'E', 'F'].contains(rowLabel)) {
      throw ArgumentError('rowLabel muss A–F sein.');
    }
    if (slot.columnNumber < 1 || slot.columnNumber > 10) {
      throw ArgumentError('columnNumber muss zwischen 1 und 10 sein.');
    }
    if (slot.maxCapacity < 1) {
      throw ArgumentError('maxCapacity muss mindestens 1 sein.');
    }
    if (slot.stockQuantity < 0 || slot.stockQuantity > slot.maxCapacity) {
      throw ArgumentError('Bestand muss zwischen 0 und maxCapacity liegen.');
    }

    final endColumn = slot.columnNumber + product.slotWidth - 1;
    if (endColumn > 10) {
      throw ArgumentError('Das Produkt passt nicht in diese Reihe.');
    }

    if (!isPlacementAllowed(
      category: product.category,
      slotWidth: product.slotWidth,
      rowLabel: rowLabel,
    )) {
      throw ArgumentError(
        'Kategorie/Breite passt nicht zu Reihe $rowLabel '
        '(Breite ${product.slotWidth}).',
      );
    }
  }

  Future<bool> _hasOverlappingSlot(
    Transaction txn, {
    required ProductSlot slot,
    required int slotWidth,
  }) async {
    final startColumn = slot.columnNumber;
    final endColumn = slot.columnNumber + slotWidth - 1;

    // Überlappung mit anderen Slots: product.slot_width per SQL-Verknüpfung nötig
    final rows = await txn.rawQuery(
      '''
      SELECT s.id, s.column_number, p.slot_width
      FROM product_slot s
      INNER JOIN product p ON p.id = s.product_id
      WHERE s.row_label = ?
        AND s.column_number <= ?
        AND (s.column_number + p.slot_width - 1) >= ?
        ${slot.id != null ? 'AND s.id != ?' : ''}
      LIMIT 1
      ''',
      [
        slot.rowLabel.toUpperCase(),
        endColumn,
        startColumn,
        if (slot.id != null) slot.id!,
      ],
    );

    return rows.isNotEmpty;
  }
}
