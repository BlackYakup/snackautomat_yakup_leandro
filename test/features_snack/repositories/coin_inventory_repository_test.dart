import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/coin_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/test_database.dart';

void main() {
  late Database database;
  late CoinRepository repository;

  setUp(() async {
    database = await openTestDatabase();
    repository = CoinRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('leere Datenbank wird mit Standardmünzen initialisiert', () async {
    final snapshot = await repository.loadSnapshot();

    expect(snapshot.inventory, {
      5: 30,
      10: 20,
      20: 20,
      50: 30,
      100: 20,
      200: 10,
    });
  });

  test('Münzbestand kann gespeichert und erneut geladen werden', () async {
    const snapshot = CoinSnapshot(
      inventory: {5: 10, 10: 11, 20: 12, 50: 13, 100: 14, 200: 15},
      surplus: {5: 1, 10: 2, 20: 3, 50: 4, 100: 5, 200: 6},
      targetStock: {5: 20, 10: 20, 20: 20, 50: 10, 100: 10, 200: 5},
      designPaths: <int, String?>{},
      changeDispenseCount: 7,
      dispenseContainerFillLevel: 2,
    );

    await repository.saveSnapshot(snapshot);
    final loaded = await repository.loadSnapshot();

    expect(loaded.inventory, snapshot.inventory);
    expect(loaded.surplus, snapshot.surplus);
    expect(loaded.targetStock, snapshot.targetStock);
    expect(loaded.changeDispenseCount, 7);
    expect(loaded.dispenseContainerFillLevel, 2);
  });

  test('erneutes Speichern erzeugt keine doppelten Münzzeilen', () async {
    const first = CoinSnapshot(
      inventory: {20: 5},
      surplus: {20: 0},
      targetStock: {20: 10},
      designPaths: <int, String?>{},
      changeDispenseCount: 0,
      dispenseContainerFillLevel: 0,
    );
    const second = CoinSnapshot(
      inventory: {20: 8},
      surplus: {20: 1},
      targetStock: {20: 10},
      designPaths: <int, String?>{},
      changeDispenseCount: 2,
      dispenseContainerFillLevel: 1,
    );

    await repository.saveSnapshot(first);
    await repository.saveSnapshot(second);

    final rows = await database.query(
      'coin_inventory',
      where: 'denomination_cents = ?',
      whereArgs: [20],
    );
    final loaded = await repository.loadSnapshot();

    expect(rows, hasLength(1));
    expect(loaded.inventory[20], 8);
    expect(loaded.surplus[20], 1);
  });
}
