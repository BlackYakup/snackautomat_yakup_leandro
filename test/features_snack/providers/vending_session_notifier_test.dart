import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/coin_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/test_database.dart';

const _testInventory = <int, int>{5: 7, 10: 8, 20: 9, 50: 6, 100: 4, 200: 3};

const _emptyInventory = <int, int>{5: 0, 10: 0, 20: 0, 50: 0, 100: 0, 200: 0};

const _zeroCoinMap = <int, int>{5: 0, 10: 0, 20: 0, 50: 0, 100: 0, 200: 0};

const _targetStock = <int, int>{
  5: 30,
  10: 20,
  20: 20,
  50: 30,
  100: 20,
  200: 10,
};

class _TestHarness {
  const _TestHarness({
    required this.database,
    required this.container,
    required this.product,
  });

  final Database database;
  final ProviderContainer container;
  final Product product;

  VendingSessionNotifier get notifier =>
      container.read(vendingSessionProvider.notifier);

  VendingSessionState get state => container.read(vendingSessionProvider);

  Future<void> dispose() async {
    container.dispose();
    await database.close();
  }
}

Future<_TestHarness> _createHarness({
  int priceCents = 160,
  int stockQuantity = 3,
  Map<int, int> inventory = _testInventory,
}) async {
  final database = await openTestDatabase();
  final productId = await seedProduct(
    database,
    priceCents: priceCents,
    stockQuantity: stockQuantity,
  );
  final product = Product(
    id: productId,
    name: 'Testprodukt',
    priceCents: priceCents,
    stockQuantity: stockQuantity,
    maxCapacity: 10,
    category: ProductCategory.snacksBars,
    rowLabel: 'C',
    columnNumber: 4,
    slotWidth: 1,
  );

  await CoinRepository(database).saveSnapshot(
    CoinSnapshot(
      inventory: inventory,
      surplus: _zeroCoinMap,
      targetStock: _targetStock,
      designPaths: const <int, String?>{},
      changeDispenseCount: 0,
      dispenseContainerFillLevel: 0,
    ),
  );

  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWith((ref) async => database)],
  );

  await container.read(productControllerProvider.future);
  container.read(vendingSessionProvider);

  await _waitUntil(
    () => mapEquals(
      container.read(vendingSessionProvider).coinInventory,
      inventory,
    ),
  );

  return _TestHarness(
    database: database,
    container: container,
    product: product,
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  throw StateError('Asynchroner Testzustand wurde nicht rechtzeitig erreicht.');
}

void main() {
  group('Slot-Timeout und Leeren', () {
    test('ein einzelner Buchstabe wird nach zwei Sekunden verworfen', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      fakeAsync((async) {
        harness.notifier.pressSlotKey('C');
        expect(harness.state.currentSlotInput, 'C');

        async.elapse(const Duration(seconds: 2));

        expect(harness.state.currentSlotInput, isEmpty);
        expect(harness.state.statusMessage, 'Ungültiger Slot');
      });
    });

    test('Leeren entfernt eine unvollständige Eingabe', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      harness.notifier.pressSlotKey('C');
      harness.notifier.clearSlotInput();

      expect(harness.state.currentSlotInput, isEmpty);
    });

    test('Leeren entfernt Produktauswahl und Slot-Code', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');
      harness.notifier.clearSlotInput();

      expect(harness.state.selectedProduct, isNull);
      expect(harness.state.selectedSlotCode, isNull);
    });

    test('Leeren behält bereits eingeworfene 100 Cent', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');
      await harness.notifier.insertCoin(100);
      harness.notifier.clearSlotInput();

      expect(harness.state.selectedProduct, isNull);
      expect(harness.state.selectedSlotCode, isNull);
      expect(harness.state.insertedAmountCents, 100);
    });

    test('Leeren beendet den laufenden Slot-Timer', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      fakeAsync((async) {
        harness.notifier.pressSlotKey('C');
        harness.notifier.clearSlotInput();

        async.elapse(const Duration(seconds: 3));

        expect(harness.state.currentSlotInput, isEmpty);
        expect(harness.state.selectedProduct, isNull);
        expect(harness.state.selectedSlotCode, isNull);
        expect(harness.state.statusMessage, isNot('Ungültiger Slot'));
      });
    });
  });

  group('Münzeinwurf', () {
    test('50 Cent bei Preis 160 lassen 110 Cent offen', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(50);

      expect(harness.state.insertedAmountCents, 50);
      expect(harness.state.missingAmountCents, 110);
      expect(harness.state.outputProduct, isNull);
    });

    test('weitere 100 Cent lassen 10 Cent offen', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(50);
      await harness.notifier.insertCoin(100);

      expect(harness.state.insertedAmountCents, 150);
      expect(harness.state.missingAmountCents, 10);
      expect(harness.state.outputProduct, isNull);
    });

    test('weitere 10 Cent lösen den automatischen Kauf aus', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(50);
      await harness.notifier.insertCoin(100);
      await harness.notifier.insertCoin(10);

      expect(harness.state.outputProduct?.id, harness.product.id);
      expect(harness.state.outputChange, isEmpty);
    });

    test('Münze ohne Produktauswahl wird nicht angenommen', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      await harness.notifier.insertCoin(50);

      expect(harness.state.insertedAmountCents, 0);
      expect(
        harness.state.statusMessage,
        'Bitte zuerst ein Produkt auswählen.',
      );
    });
  });

  group('Automatischer Kauf', () {
    test('zu wenig Geld löst keinen Kauf aus', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(100);

      expect(harness.state.outputProduct, isNull);
    });

    test('exakte Zahlung löst einen Kauf aus', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(100);
      await harness.notifier.insertCoin(50);
      await harness.notifier.insertCoin(10);

      expect(harness.state.outputProduct?.id, harness.product.id);
      expect(harness.state.outputChange, isEmpty);
    });

    test('Überzahlung löst Kauf mit Wechselgeld aus', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(200);

      expect(harness.state.outputProduct?.id, harness.product.id);
      expect(harness.state.outputChange, {20: 2});
    });

    test('ausverkauftes Produkt blockiert den Kauf', () async {
      final harness = await _createHarness(stockQuantity: 0);
      addTearDown(harness.dispose);

      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');
      await harness.notifier.insertCoin(200);

      expect(harness.state.outputProduct, isNull);
      expect(
        harness.state.statusMessage.toLowerCase(),
        contains('ausverkauft'),
      );
    });

    test('Kauf ohne Produkt wird blockiert', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      await harness.notifier.buySelectedProduct();

      expect(harness.state.outputProduct, isNull);
      expect(harness.state.statusMessage, 'Kein Produkt ausgewählt.');
    });

    test('nicht mögliches Wechselgeld blockiert den Kauf', () async {
      final harness = await _createHarness(inventory: _emptyInventory);
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(200);

      expect(harness.state.outputProduct, isNull);
      expect(harness.state.statusMessage, 'Wechselgeld nicht möglich.');
    });
  });

  group('Bestand, Münzinventar und Transaktion', () {
    test('erfolgreicher Kauf reduziert Bestand von 3 auf 2', () async {
      final harness = await _createHarness(stockQuantity: 3);
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(100);
      await harness.notifier.insertCoin(50);
      await harness.notifier.insertCoin(10);

      final rows = await harness.database.query(
        'product',
        columns: ['stock_quantity'],
        where: 'id = ?',
        whereArgs: [harness.product.id],
      );

      expect(rows.single['stock_quantity'], 2);
    });

    test('Bestand 0 wird nicht weiter reduziert', () async {
      final harness = await _createHarness(stockQuantity: 0);
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(200);

      final rows = await harness.database.query(
        'product',
        columns: ['stock_quantity'],
        where: 'id = ?',
        whereArgs: [harness.product.id],
      );

      expect(rows.single['stock_quantity'], 0);
      expect(harness.state.outputProduct, isNull);
    });

    test('eingeworfene Münze wird addiert und Wechselgeld abgezogen', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final before200 = harness.state.coinInventory[200]!;
      final before20 = harness.state.coinInventory[20]!;
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(200);

      expect(harness.state.outputChange, {20: 2});
      expect(harness.state.coinInventory[200], before200 + 1);
      expect(harness.state.coinInventory[20], before20 - 2);
    });

    test('erfolgreicher Kauf speichert genau eine Transaktion', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(200);

      final rows = await harness.database.query('transactions');
      final transaction = rows.single;

      expect(rows, hasLength(1));
      expect(transaction['product_id'], harness.product.id);
      expect(transaction['amount_paid_cents'], 200);
      expect(transaction['change_given_cents'], 40);
      expect(transaction['status'], 'completed');
      expect(DateTime.tryParse(transaction['created_at'] as String), isNotNull);
    });

    test('fehlgeschlagener Kauf speichert keine Transaktion', () async {
      final harness = await _createHarness(inventory: _emptyInventory);
      addTearDown(harness.dispose);
      harness.notifier.selectProduct(harness.product, selectedSlotCode: 'C4');

      await harness.notifier.insertCoin(200);

      final rows = await harness.database.query('transactions');
      expect(rows, isEmpty);
    });
  });
}
