import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_004_product_visual_fields.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_005_product_model_path.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_006_product_model_part.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_007_coin_state_fields.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_008_coin_earned_surplus.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_009_coin_own_quantity.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('additive migrations skip columns that already exist', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE product(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              max_capacity INTEGER NOT NULL DEFAULT 10
            );
          ''');
          await database.execute('''
            CREATE TABLE coin_inventory(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              denomination_cents INTEGER NOT NULL UNIQUE,
              quantity INTEGER NOT NULL
            );
          ''');
        },
        version: 1,
      ),
    );

    addTearDown(db.close);

    const migrations = [
      Migration004ProductVisualFields(),
      Migration005ProductModelPath(),
      Migration006ProductModelPart(),
      Migration007CoinStateFields(),
      Migration008CoinEarnedSurplus(),
      Migration009CoinOwnQuantity(),
    ];

    for (final migration in migrations) {
      await migration.up(db);
      await migration.up(db);
    }

    final productColumns = await db.rawQuery('PRAGMA table_info(product)');
    final productColumnNames = productColumns.map((row) => row['name']).toSet();

    expect(
      productColumnNames,
      containsAll([
        'max_capacity',
        'image_path',
        'icon_key',
        'model_path',
        'model_part',
      ]),
    );

    final coinColumns = await db.rawQuery('PRAGMA table_info(coin_inventory)');
    final coinColumnNames = coinColumns.map((row) => row['name']).toSet();

    expect(
      coinColumnNames,
      containsAll([
        'surplus_quantity',
        'target_quantity',
        'design_path',
        'earned_surplus_quantity',
        'own_quantity',
      ]),
    );
  });

  test('Migration 9 übernimmt vorhandene Münzen als Herkunftsbestand', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE coin_inventory(
              denomination_cents INTEGER PRIMARY KEY,
              quantity INTEGER NOT NULL,
              surplus_quantity INTEGER NOT NULL,
              earned_surplus_quantity INTEGER NOT NULL
            );
          ''');
          await database.insert('coin_inventory', {
            'denomination_cents': 20,
            'quantity': 20,
            'surplus_quantity': 5,
            'earned_surplus_quantity': 7,
          });
        },
        version: 1,
      ),
    );

    addTearDown(db.close);

    await const Migration009CoinOwnQuantity().up(db);

    final rows = await db.query('coin_inventory');
    expect(rows.single['own_quantity'], 18);
  });
}
