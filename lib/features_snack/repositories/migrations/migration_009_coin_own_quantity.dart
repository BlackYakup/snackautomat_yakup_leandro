import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class Migration009CoinOwnQuantity extends Migration {
  const Migration009CoinOwnQuantity();

  @override
  int get version => 9;

  @override
  Future<void> up(Database db) async {
    final columnNames = await getTableColumnNames(db, 'coin_inventory');

    if (columnNames.contains('own_quantity')) {
      return;
    }

    await db.execute('''
      ALTER TABLE coin_inventory
      ADD COLUMN own_quantity INTEGER NOT NULL DEFAULT 0;
    ''');

    await db.execute('''
      UPDATE coin_inventory
      SET own_quantity = CASE
        WHEN quantity + surplus_quantity - earned_surplus_quantity > 0
        THEN quantity + surplus_quantity - earned_surplus_quantity
        ELSE 0
      END;
    ''');
  }
}
