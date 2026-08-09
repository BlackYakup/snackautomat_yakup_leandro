import 'package:json_annotation/json_annotation.dart';

enum ProductCategory {
  drinks('drinks'),
  snacksBars('snacks_bars'),
  chips('chips'),
  sweetsCookies('sweets_cookies'),
  knabberMints('knabber_mints'),
  fitness('fitness');

  const ProductCategory(this.dbValue);

  final String dbValue;

  static ProductCategory fromDbValue(String value) {
    return ProductCategory.values.firstWhere(
      (category) => category.dbValue == value,
      orElse: () => throw ArgumentError('Unknown product category: $value')
    );
  }
}

class ProductCategoryConverter implements JsonConverter<ProductCategory, String> {
  const ProductCategoryConverter();

  @override
  ProductCategory fromJson(String json) {
    return ProductCategory.fromDbValue(json);
  }

  @override
  String toJson(ProductCategory object) {
    return object.dbValue;
  }
}

bool isCategoryAllowedInRow(ProductCategory category, String rowLabel) {
  return isPlacementAllowed(
    category: category,
    slotWidth: category == ProductCategory.drinks ||
            category == ProductCategory.snacksBars ||
            category == ProductCategory.chips ||
            category == ProductCategory.sweetsCookies
        ? 1
        : 2,
    rowLabel: rowLabel,
  );
}

/// Breite 1: A–B Getränke, C–D schmale Snacks. Breite 2: E–F Doppel-Slots.
bool isPlacementAllowed({
  required ProductCategory category,
  required int slotWidth,
  required String rowLabel,
}) {
  final row = rowLabel.toUpperCase();

  if (slotWidth == 2) {
    return row == 'E' || row == 'F';
  }

  if (slotWidth != 1) {
    return false;
  }

  if (row == 'A' || row == 'B') {
    return category == ProductCategory.drinks;
  }

  if (row == 'C' || row == 'D') {
    return category != ProductCategory.drinks;
  }

  return false;
}

List<String> allowedRowsForProduct({
  required ProductCategory category,
  required int slotWidth,
}) {
  return ['A', 'B', 'C', 'D', 'E', 'F']
      .where(
        (row) => isPlacementAllowed(
          category: category,
          slotWidth: slotWidth,
          rowLabel: row,
        ),
      )
      .toList();
}