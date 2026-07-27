import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/transaction_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/test_database.dart';

void main() {
  late Database database;
  late TransactionRepository repository;

  setUp(() async {
    database = await openTestDatabase();
    repository = TransactionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('recordSale speichert genau eine vollständige Transaktion', () async {
    final productId = await seedProduct(database);
    final earliestExpectedTime = DateTime.now().subtract(
      const Duration(seconds: 1),
    );

    await repository.recordSale(
      productId: productId,
      amountPaidCents: 200,
      changeGivenCents: 40,
    );

    final rows = await database.query('transactions');
    final transaction = rows.single;
    final createdAt = DateTime.tryParse(transaction['created_at'] as String);

    expect(rows, hasLength(1));
    expect(transaction['product_id'], productId);
    expect(transaction['amount_paid_cents'], 200);
    expect(transaction['change_given_cents'], 40);
    expect(transaction['status'], 'completed');
    expect(createdAt, isNotNull);
    expect(createdAt!.isBefore(earliestExpectedTime), isFalse);
  });
}
