// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Product _$ProductFromJson(Map<String, dynamic> json) => _Product(
  name: json['name'] as String,
  id: (json['id'] as num?)?.toInt(),
  priceCents: (json['price_cents'] as num).toInt(),
  stockQuantity: (json['stock_quantity'] as num).toInt(),
  category: const ProductCategoryConverter().fromJson(
    json['category'] as String,
  ),
  rowLabel: json['row_label'] as String,
  columnNumber: (json['column_number'] as num).toInt(),
  slotWidth: (json['slot_width'] as num).toInt(),
);

Map<String, dynamic> _$ProductToJson(_Product instance) => <String, dynamic>{
  'name': instance.name,
  'id': instance.id,
  'price_cents': instance.priceCents,
  'stock_quantity': instance.stockQuantity,
  'category': const ProductCategoryConverter().toJson(instance.category),
  'row_label': instance.rowLabel,
  'column_number': instance.columnNumber,
  'slot_width': instance.slotWidth,
};
