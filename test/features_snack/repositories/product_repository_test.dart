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

  test('getProducts liest gespeicherte Produkte in Slot-Reihenfolge', () async {
    await seedProduct(database, name: 'C5', rowLabel: 'C', columnNumber: 5);
    await seedProduct(database, name: 'C4', rowLabel: 'C', columnNumber: 4);

    final products = await repository.getProducts();

    expect(products.map((product) => product.name), ['C4', 'C5']);
  });

  test('updateStockQuantity speichert den neuen Bestand', () async {
    final productId = await seedProduct(database, stockQuantity: 3);

    await repository.updateStockQuantity(
      productId: productId,
      stockQuantity: 2,
    );

    final rows = await database.query(
      'product',
      columns: ['stock_quantity'],
      where: 'id = ?',
      whereArgs: [productId],
    );

    expect(rows.single['stock_quantity'], 2);
  });

  test('saveProductAtSlot speichert ein neues gültiges Produkt', () async {
    const product = Product(
      name: 'Mars',
      priceCents: 160,
      stockQuantity: 3,
      maxCapacity: 10,
      category: ProductCategory.snacksBars,
      rowLabel: 'C',
      columnNumber: 4,
      slotWidth: 1,
    );

    await repository.saveProductAtSlot(product);

    final products = await repository.getProducts();
    expect(products, hasLength(1));
    expect(products.single.name, 'Mars');
    expect(products.single.rowLabel, 'C');
    expect(products.single.columnNumber, 4);
  });

  test('saveProductAtSlot blockiert überlappende Slots', () async {
    const wideProduct = Product(
      name: 'Breites Produkt',
      priceCents: 200,
      stockQuantity: 2,
      maxCapacity: 10,
      category: ProductCategory.snacksBars,
      rowLabel: 'C',
      columnNumber: 4,
      slotWidth: 2,
    );
    const overlappingProduct = Product(
      name: 'Überlappendes Produkt',
      priceCents: 150,
      stockQuantity: 2,
      maxCapacity: 10,
      category: ProductCategory.snacksBars,
      rowLabel: 'C',
      columnNumber: 5,
      slotWidth: 1,
    );

    await repository.saveProductAtSlot(wideProduct);

    expect(
      () => repository.saveProductAtSlot(overlappingProduct),
      throwsA(isA<StateError>()),
    );
  });

  test('deleteProduct entfernt genau das angegebene Produkt', () async {
    final firstId = await seedProduct(database, name: 'Mars', columnNumber: 4);
    await seedProduct(database, name: 'Snickers', columnNumber: 5);

    await repository.deleteProduct(firstId);

    final products = await repository.getProducts();
    expect(products, hasLength(1));
    expect(products.single.name, 'Snickers');
  });
}
