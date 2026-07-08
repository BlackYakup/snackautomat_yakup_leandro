import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
abstract class Product with _$Product {
  const factory Product({
    required String name,
    required int id,
    required int price,
    required String slotNumber,
    required int stockQuantity,
    required bool isSoldOut
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
    _$ProductFromJson(json);
}