import 'package:sqflite/sqflite.dart';

class TransactionRepository {
  const TransactionRepository(this.db);

  final Database db;

  Future<void> recordSale({
    required int productId,
    required int amountPaidCents,
    required int changeGivenCents,
  }) async {
    await db.insert('transactions', {
      'product_id': productId,
      'amount_paid_cents': amountPaidCents,
      'change_given_cents': changeGivenCents,
      'status': 'completed',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
