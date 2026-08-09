import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class Migration007CoinStateFields extends Migration {
  const Migration007CoinStateFields();

  @override
  int get version => 7;

  @override
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS machine_settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    final columnNames = await getTableColumnNames(db, 'coin_inventory');

    if (!columnNames.contains('surplus_quantity')) {
      await db.execute('''
        ALTER TABLE coin_inventory
        ADD COLUMN surplus_quantity INTEGER NOT NULL DEFAULT 0;
      ''');
    }

    if (!columnNames.contains('target_quantity')) {
      await db.execute('''
        ALTER TABLE coin_inventory
        ADD COLUMN target_quantity INTEGER NOT NULL DEFAULT 0;
      ''');
    }

    if (!columnNames.contains('design_path')) {
      await db.execute('''
        ALTER TABLE coin_inventory
        ADD COLUMN design_path TEXT;
      ''');
    }
  }
}
