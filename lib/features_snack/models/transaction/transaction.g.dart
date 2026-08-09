// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Transaction _$TransactionFromJson(Map<String, dynamic> json) => _Transaction(
  id: (json['id'] as num).toInt(),
  productId: (json['productId'] as num).toInt(),
  amountPaid: (json['amountPaid'] as num).toInt(),
  changeGiven: (json['changeGiven'] as num).toInt(),
  status: json['status'] as String,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$TransactionToJson(_Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'productId': instance.productId,
      'amountPaid': instance.amountPaid,
      'changeGiven': instance.changeGiven,
      'status': instance.status,
      'createdAt': instance.createdAt,
    };
