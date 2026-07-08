// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Product _$ProductFromJson(Map<String, dynamic> json) => _Product(
  name: json['name'] as String,
  id: (json['id'] as num).toInt(),
  price: (json['price'] as num).toInt(),
  slotNumber: json['slotNumber'] as String,
  stockQuantity: (json['stockQuantity'] as num).toInt(),
  isSoldOut: json['isSoldOut'] as bool,
);

Map<String, dynamic> _$ProductToJson(_Product instance) => <String, dynamic>{
  'name': instance.name,
  'id': instance.id,
  'price': instance.price,
  'slotNumber': instance.slotNumber,
  'stockQuantity': instance.stockQuantity,
  'isSoldOut': instance.isSoldOut,
};
