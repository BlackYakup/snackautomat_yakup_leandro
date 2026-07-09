import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:sqflite/sqflite.dart';

class ProductRepository {
  const ProductRepository(this.db);

  final Database db;

  Future<List<Product>> getProducts() async {
    final rows = await db.query(
      'product',
      orderBy: 'row_label ASC, column_number ASC'
    );

    return rows.map((row) => Product.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> saveProductAtSlot(Product product) async {
    _validateProductPlacement(product);

    await db.transaction((txn) async {
      final hasOverlap = await _hasOverlappingProduct(txn, product);

      if (hasOverlap) {
        throw StateError('Slot is already occupied.');
      }

      final values = Map<String, Object?>.from(product.toJson())..removeWhere((key, value) => value == null);

      values['row_label'] = product.rowLabel.toUpperCase();

      if (product.id == null) {
        await txn.insert('product', values);
      }
      else {
        await txn.update(
          'product',
          values,
          where: 'id = ?',
          whereArgs: [product.id]
        );
      }
    });
  }

  void _validateProductPlacement(Product product) {
    final rowLabel = product.rowLabel.toUpperCase();

    if (!['A', 'B', 'C', 'D', 'E', 'F'].contains(rowLabel)) {
      throw ArgumentError('rowLabel muss A, B, C, D, E, F sein.');
    }

    if (product.columnNumber < 1 || product.columnNumber > 10) {
      throw ArgumentError('columnNumber muss zwischen 1 und 10 sein.');
    }

    if (product.slotWidth != 1 && product.slotWidth != 2) {
      throw ArgumentError('slotWidth muss 1 oder 2 sein.');
    }

    final endColumn = product.columnNumber + product.slotWidth - 1;

    if (endColumn > 10) {
      throw ArgumentError('Das Produkt passt nicht in diese Reihe.');
    }
    if (!isCategoryAllowedInRow(product.category, rowLabel)) {
      throw ArgumentError('Diese Kategorie ist in dieser Reihe nicht erlaubt.');
    }
  }

  Future<bool> _hasOverlappingProduct(Transaction txn, Product product) async {
    final startColumn = product.columnNumber;
    final endColumn = product.columnNumber + product.slotWidth - 1;

    var where = """
      row_label = ?
      AND column_number <= ?
      AND (column_number + slot_width -1) >= ?
    """;

    final whereArgs = <Object>[
      product.rowLabel.toUpperCase(),
      endColumn,
      startColumn
    ];

    final productId = product.id;

    if (productId != null) {
      where += " AND id != ?";
      whereArgs.add(productId);
    }

    final rows = await txn.query(
      'product',
      where: where,
      whereArgs: whereArgs,
      limit: 1
    );

    return rows.isNotEmpty;
  }
}