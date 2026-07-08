import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class Migration002ProductLayoutFields extends Migration {
  const Migration002ProductLayoutFields();

  @override
  int get version => 2;

  @override
  Future<void> up(Database db) async {
    await db.execute("ALTER TABLE product RENAME TO product_old;");

    await db.execute("""
      CREATE TABLE product(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price_cents INTEGER NOT NULL,
        stock_quantity INTEGER NOT NULL,
        category TEXT NOT NULL,
        row_label TEXT NOT NULL CHECK(row_label IN ('A', 'B', 'C', 'D', 'E', 'F')),
        column_number INTEGER NOT NULL CHECK(column_number BETWEEN 1 AND 10),
        slot_width INTEGER NOT NULL DEFAULT 1 CHECK(slot_width IN(1, 2))
      );
    """);

    await db.execute("""
      INSERT INTO product (
        id,
        name,
        price_cents,
        stock_quantity,
        category,
        row_label,
        column_number,
        slot_width
      )
      SELECT
        id,
        name,
        price_cents,
        stock_quantity,
        'snacks_bars',
        CASE
          WHEN slot_number BETWEEN 1 AND 60
          THEN substr('ABCDEF', CAST(((slot_number - 1) / 10) AS INTEGER) + 1, 1)
          ELSE 'C'
        END,
        CASE
          WHEN slot_number BETWEEN 1 AND 60
          THEN ((slot_number -1) % 10) + 1
          ELSE 1
        END,
        1
      FROM product_old;
    """);

    await db.execute("DROP TABLE product_old;");
  }
}