// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_slot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProductSlot _$ProductSlotFromJson(Map<String, dynamic> json) => _ProductSlot(
  id: (json['id'] as num?)?.toInt(),
  productId: (json['product_id'] as num).toInt(),
  rowLabel: json['row_label'] as String,
  columnNumber: (json['column_number'] as num).toInt(),
  stockQuantity: (json['stock_quantity'] as num).toInt(),
  maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 10,
);

Map<String, dynamic> _$ProductSlotToJson(_ProductSlot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'product_id': instance.productId,
      'row_label': instance.rowLabel,
      'column_number': instance.columnNumber,
      'stock_quantity': instance.stockQuantity,
      'max_capacity': instance.maxCapacity,
    };
