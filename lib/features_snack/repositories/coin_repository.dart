import 'package:snackautomat_yakup_leandro/features_snack/constants/vending_coin_config.dart';
import 'package:sqflite/sqflite.dart';

class CoinSnapshot {
  const CoinSnapshot({
    required this.inventory,
    required this.surplus,
    required this.earnedSurplus,
    required this.targetStock,
    required this.designPaths,
    required this.changeDispenseCount,
    required this.dispenseContainerFillLevel,
  });

  final Map<int, int> inventory;
  final Map<int, int> surplus;
  final Map<int, int> earnedSurplus;
  final Map<int, int> targetStock;
  final Map<int, String?> designPaths;
  final int changeDispenseCount;
  final int dispenseContainerFillLevel;
}

class CoinRepository {
  const CoinRepository(this.db);

  final Database db;

  static const _changeDispenseKey = 'change_dispense_count';
  static const _dispenseFillKey = 'dispense_container_fill_level';

  Future<CoinSnapshot> loadSnapshot() async {
    final rows = await db.query('coin_inventory');

    if (rows.isEmpty) {
      await _seedDefaults();
      return loadSnapshot();
    }

    final inventory = <int, int>{};
    final surplus = <int, int>{};
    final earnedSurplus = <int, int>{};
    final targetStock = <int, int>{};
    final designPaths = <int, String?>{};

    for (final denomination in coinDenominationsCents) {
      inventory[denomination] = 0;
      surplus[denomination] = 0;
      earnedSurplus[denomination] = 0;
      targetStock[denomination] = defaultCoinTargetStock[denomination] ?? 0;
      designPaths[denomination] = null;
    }

    for (final row in rows) {
      final denomination = row['denomination_cents'] as int;
      inventory[denomination] = row['quantity'] as int? ?? 0;
      surplus[denomination] = row['surplus_quantity'] as int? ?? 0;
      earnedSurplus[denomination] = row['earned_surplus_quantity'] as int? ?? 0;
      targetStock[denomination] =
          row['target_quantity'] as int? ??
          defaultCoinTargetStock[denomination] ??
          0;
      designPaths[denomination] = row['design_path'] as String?;
    }

    return CoinSnapshot(
      inventory: inventory,
      surplus: surplus,
      earnedSurplus: earnedSurplus,
      targetStock: targetStock,
      designPaths: designPaths,
      changeDispenseCount: await _readIntSetting(
        _changeDispenseKey,
        defaultValue: 20,
      ),
      dispenseContainerFillLevel: await _readIntSetting(
        _dispenseFillKey,
        defaultValue: 1,
      ),
    );
  }

  Future<void> saveSnapshot(CoinSnapshot snapshot) async {
    await db.transaction((txn) async {
      for (final denomination in coinDenominationsCents) {
        await txn.insert('coin_inventory', {
          'denomination_cents': denomination,
          'quantity': snapshot.inventory[denomination] ?? 0,
          'surplus_quantity': snapshot.surplus[denomination] ?? 0,
          'earned_surplus_quantity': snapshot.earnedSurplus[denomination] ?? 0,
          'target_quantity': snapshot.targetStock[denomination] ?? 0,
          'design_path': snapshot.designPaths[denomination],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await txn.insert('machine_settings', {
        'key': _changeDispenseKey,
        'value': '${snapshot.changeDispenseCount}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('machine_settings', {
        'key': _dispenseFillKey,
        'value': '${snapshot.dispenseContainerFillLevel}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> _seedDefaults() async {
    await db.transaction((txn) async {
      for (final denomination in coinDenominationsCents) {
        await txn.insert('coin_inventory', {
          'denomination_cents': denomination,
          'quantity': defaultCoinInventory[denomination] ?? 0,
          'surplus_quantity': defaultCoinSurplus[denomination] ?? 0,
          'earned_surplus_quantity':
              defaultCoinEarnedSurplus[denomination] ?? 0,
          'target_quantity': defaultCoinTargetStock[denomination] ?? 0,
        });
      }
    });
  }

  Future<int> _readIntSetting(String key, {required int defaultValue}) async {
    final rows = await db.query(
      'machine_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return defaultValue;
    }

    return int.tryParse(rows.first['value'] as String? ?? '') ?? defaultValue;
  }
}
