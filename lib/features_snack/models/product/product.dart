import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
abstract class Product with _$Product {
  const Product._();

  const factory Product({
    required String name,
    int? id,
    @JsonKey(name: 'price_cents') required int priceCents,
    @JsonKey(name: 'stock_quantity') required int stockQuantity,
    @ProductCategoryConverter() required ProductCategory category,
    @JsonKey(name: 'row_label') required String rowLabel,
    @JsonKey(name: 'column_number') required int columnNumber,
    @JsonKey(name: 'slot_width') required int slotWidth
  }) = _Product;

  bool get isSoldOut => stockQuantity <= 0;

  factory Product.fromJson(Map<String, dynamic> json) =>
    _$ProductFromJson(json);
}