// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Product _$ProductFromJson(Map<String, dynamic> json) => _Product(
  name: json['name'] as String,
  id: (json['id'] as num?)?.toInt(),
  priceCents: (json['price_cents'] as num).toInt(),
  maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 10,
  category: const ProductCategoryConverter().fromJson(
    json['category'] as String,
  ),
  slotWidth: (json['slot_width'] as num).toInt(),
  imagePath: json['image_path'] as String?,
  modelPath: json['model_path'] as String?,
  modelPart: json['model_part'] as String?,
  iconKey: json['icon_key'] as String?,
);

Map<String, dynamic> _$ProductToJson(_Product instance) => <String, dynamic>{
  'name': instance.name,
  'id': instance.id,
  'price_cents': instance.priceCents,
  'max_capacity': instance.maxCapacity,
  'category': const ProductCategoryConverter().toJson(instance.category),
  'slot_width': instance.slotWidth,
  'image_path': instance.imagePath,
  'model_path': instance.modelPath,
  'model_part': instance.modelPart,
  'icon_key': instance.iconKey,
};
