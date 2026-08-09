import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/product_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/test_database.dart';

void main() {
  late Database database;
  late ProductRepository repository;

  setUp(() async {
    database = await openTestDatabase();
    repository = ProductRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('getProducts liefert Katalog sortiert', () async {
    await seedProduct(database, name: 'C5', rowLabel: 'C', columnNumber: 5);
    await seedProduct(database, name: 'C4', rowLabel: 'C', columnNumber: 4);

    final products = await repository.getProducts();
    expect(products.map((p) => p.name), containsAll(['C4', 'C5']));
  });

  test('updateSlotStock ändert Bestand', () async {
    final productId = await seedProduct(database, stockQuantity: 3);
    final placed = await repository.getPlacedProducts();
    final slotId = placed.single.slotId!;

    await repository.updateSlotStock(slotId: slotId, stockQuantity: 2);
    final updated = await repository.getPlacedProducts();
    expect(updated.single.stockQuantity, 2);
    expect(updated.single.product.id, productId);
  });

  test('saveProduct speichert Katalog ohne Slot', () async {
    const product = Product(
      name: 'Mars',
      priceCents: 150,
      maxCapacity: 10,
      category: ProductCategory.snacksBars,
      slotWidth: 1,
    );

    final id = await repository.saveProduct(product);
    final products = await repository.getProducts();
    expect(products.single.id, id);
    expect(products.single.slotWidth, 1);
    expect(await repository.getPlacedProducts(), isEmpty);
  });

  test('assignProductToSlot blockiert Überlappung', () async {
    final wide = Product(
      name: 'Chips',
      priceCents: 200,
      maxCapacity: 6,
      category: ProductCategory.chips,
      slotWidth: 2,
    );
    // Breite 2 nur auf E/F erlaubt
    final wideId = await repository.saveProduct(wide);
    await repository.assignProductToSlot(
      product: wide.copyWith(id: wideId),
      rowLabel: 'E',
      columnNumber: 4,
      stockQuantity: 2,
    );

    final otherId = await repository.saveProduct(
      const Product(
        name: 'Other',
        priceCents: 100,
        maxCapacity: 5,
        category: ProductCategory.knabberMints,
        slotWidth: 2,
      ),
    );

    expect(
      () => repository.assignProductToSlot(
        product: Product(
          id: otherId,
          name: 'Other',
          priceCents: 100,
          maxCapacity: 5,
          category: ProductCategory.knabberMints,
          slotWidth: 2,
        ),
        rowLabel: 'E',
        columnNumber: 5,
        stockQuantity: 1,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('deleteProduct entfernt auch Slots', () async {
    final firstId = await seedProduct(database, name: 'Mars', columnNumber: 4);
    await seedProduct(database, name: 'Snickers', columnNumber: 5);

    await repository.deleteProduct(firstId);
    final products = await repository.getProducts();
    expect(products.map((p) => p.name), ['Snickers']);
    final placed = await repository.getPlacedProducts();
    expect(placed.map((p) => p.name), ['Snickers']);
  });
}
