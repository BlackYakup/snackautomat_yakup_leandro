import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
abstract class Product with _$Product {
  const Product._();

  /// Katalog-Produkt ohne physische Slot-Position.
  /// [slotWidth] bestimmt zulässige Reihen (1 → A–D, 2 → E–F).
  const factory Product({
    required String name,
    int? id,
    @JsonKey(name: 'price_cents') required int priceCents,
    @JsonKey(name: 'max_capacity') @Default(10) int maxCapacity,
    @ProductCategoryConverter() required ProductCategory category,
    @JsonKey(name: 'slot_width') required int slotWidth,
    @JsonKey(name: 'image_path') String? imagePath,
    @JsonKey(name: 'model_path') String? modelPath,
    @JsonKey(name: 'model_part') String? modelPart,
    @JsonKey(name: 'icon_key') String? iconKey,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}
