import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required int id,
    required int productId,
    required int amountPaid,
    required int changeGiven,
    required String status,
    required String createdAt
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
    _$TransactionFromJson(json);
} 