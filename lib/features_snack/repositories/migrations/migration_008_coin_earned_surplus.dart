import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class Migration008CoinEarnedSurplus extends Migration {
  const Migration008CoinEarnedSurplus();

  @override
  int get version => 8;

  @override
  Future<void> up(Database db) async {
    final columnNames = await getTableColumnNames(db, 'coin_inventory');

    if (!columnNames.contains('earned_surplus_quantity')) {
      await db.execute('''
        ALTER TABLE coin_inventory
        ADD COLUMN earned_surplus_quantity INTEGER NOT NULL DEFAULT 0;
      ''');
    }
  }
}
