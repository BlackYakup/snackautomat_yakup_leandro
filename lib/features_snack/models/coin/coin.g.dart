// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Coin _$CoinFromJson(Map<String, dynamic> json) => _Coin(
  id: (json['id'] as num).toInt(),
  quantity: (json['quantity'] as num).toInt(),
  denomination: (json['denomination'] as num).toInt(),
);

Map<String, dynamic> _$CoinToJson(_Coin instance) => <String, dynamic>{
  'id': instance.id,
  'quantity': instance.quantity,
  'denomination': instance.denomination,
};
