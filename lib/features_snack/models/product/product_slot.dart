import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_slot.freezed.dart';
part 'product_slot.g.dart';

@freezed
abstract class ProductSlot with _$ProductSlot {
  const ProductSlot._();

  const factory ProductSlot({
    int? id,
    @JsonKey(name: 'product_id') required int productId,
    @JsonKey(name: 'row_label') required String rowLabel,
    @JsonKey(name: 'column_number') required int columnNumber,
    @JsonKey(name: 'stock_quantity') required int stockQuantity,
    @JsonKey(name: 'max_capacity') @Default(10) int maxCapacity,
  }) = _ProductSlot;

  bool get isSoldOut => stockQuantity <= 0;

  bool get isAtMaxCapacity => stockQuantity >= maxCapacity;

  String get slotCode => '${rowLabel.toUpperCase()}$columnNumber';

  factory ProductSlot.fromJson(Map<String, dynamic> json) =>
      _$ProductSlotFromJson(json);
}
