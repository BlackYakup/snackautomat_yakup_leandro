import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class Migration003IndexesAndConstraints extends Migration {
  const Migration003IndexesAndConstraints();

  @override
  int get version => 3;

  @override
  Future<void> up(Database db) async {
    await db.execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS idx_product_position_start
      ON product(row_label, column_number);
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_product_category
      ON product(category);
    """);

    await db.execute("""
      CREATE INDEX IF NOT EXISTS idx_transactions_product_id
      ON transactions(product_id);
    """);
  }
}