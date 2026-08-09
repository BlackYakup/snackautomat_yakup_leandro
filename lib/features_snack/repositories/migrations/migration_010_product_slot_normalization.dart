import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

/// Normalisiert Produktkatalog und Slot-Belegung in getrennte Tabellen.
class Migration010ProductSlotNormalization extends Migration {
  const Migration010ProductSlotNormalization();

  @override
  int get version => 10;

  @override
  Future<void> up(Database db) async {
    await db.transaction((txn) async {
      final columnInfo = await txn.rawQuery('PRAGMA table_info("product")');
      final columnNames = columnInfo.map((r) => r['name'] as String).toSet();
      final hasLegacySlots = columnNames.contains('row_label') &&
          columnNames.contains('column_number');

      await txn.execute('ALTER TABLE product RENAME TO product_legacy;');

      await txn.execute('''
        CREATE TABLE product(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price_cents INTEGER NOT NULL,
          max_capacity INTEGER NOT NULL DEFAULT 10,
          category TEXT NOT NULL,
          slot_width INTEGER NOT NULL DEFAULT 1 CHECK(slot_width IN (1, 2)),
          image_path TEXT,
          model_path TEXT,
          model_part TEXT,
          icon_key TEXT
        );
      ''');

      await txn.execute('''
        CREATE TABLE product_slot(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          row_label TEXT NOT NULL CHECK(row_label IN ('A', 'B', 'C', 'D', 'E', 'F')),
          column_number INTEGER NOT NULL CHECK(column_number BETWEEN 1 AND 10),
          stock_quantity INTEGER NOT NULL DEFAULT 0,
          max_capacity INTEGER NOT NULL DEFAULT 10,
          FOREIGN KEY(product_id) REFERENCES product(id) ON DELETE CASCADE,
          UNIQUE(row_label, column_number)
        );
      ''');

      final rows = await txn.query('product_legacy', orderBy: 'id ASC');
      for (final row in rows) {
        final productId = await txn.insert('product', {
          'id': row['id'],
          'name': row['name'],
          'price_cents': row['price_cents'],
          'max_capacity': row['max_capacity'] ?? 10,
          'category': row['category'] ?? 'snacks_bars',
          'slot_width': row['slot_width'] ?? 1,
          'image_path': row['image_path'],
          'model_path': row['model_path'],
          'model_part': row['model_part'],
          'icon_key': row['icon_key'],
        });

        if (!hasLegacySlots) {
          continue;
        }

        final rowLabel = (row['row_label'] as String?)?.toUpperCase();
        final columnNumber = row['column_number'] as int?;
        if (rowLabel == null ||
            columnNumber == null ||
            !const ['A', 'B', 'C', 'D', 'E', 'F'].contains(rowLabel)) {
          continue;
        }

        await txn.insert('product_slot', {
          'product_id': productId,
          'row_label': rowLabel,
          'column_number': columnNumber,
          'stock_quantity': row['stock_quantity'] ?? 0,
          'max_capacity': row['max_capacity'] ?? 10,
        });
      }

      await txn.execute('DROP TABLE product_legacy;');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_product_slot_product '
        'ON product_slot(product_id);',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_product_category ON product(category);',
      );
    });
  }
}
