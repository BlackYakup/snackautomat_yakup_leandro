import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_slot.dart';

/// Produkt + konkrete Slot-Belegung für Raster/Kauf.
class PlacedProduct {
  const PlacedProduct({
    required this.product,
    required this.slot,
  });

  final Product product;
  final ProductSlot slot;

  int? get id => product.id;
  int? get slotId => slot.id;
  String get name => product.name;
  int get priceCents => product.priceCents;
  ProductCategory get category => product.category;
  int get slotWidth => product.slotWidth;
  String? get imagePath => product.imagePath;
  String? get modelPath => product.modelPath;
  String? get modelPart => product.modelPart;
  String? get iconKey => product.iconKey;

  String get rowLabel => slot.rowLabel;
  int get columnNumber => slot.columnNumber;
  int get stockQuantity => slot.stockQuantity;
  int get maxCapacity => slot.maxCapacity;
  String get slotCode => slot.slotCode;

  bool get isSoldOut => slot.isSoldOut;
  bool get isAtMaxCapacity => slot.isAtMaxCapacity;

  PlacedProduct copyWithStock(int stockQuantity) {
    return PlacedProduct(
      product: product,
      slot: slot.copyWith(stockQuantity: stockQuantity),
    );
  }

  PlacedProduct copyWith({
    Product? product,
    ProductSlot? slot,
  }) {
    return PlacedProduct(
      product: product ?? this.product,
      slot: slot ?? this.slot,
    );
  }
}
