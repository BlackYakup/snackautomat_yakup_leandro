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
  switch (rowLabel.toUpperCase()) {
    case 'A':
    case 'B':
      return category == ProductCategory.drinks;
    case 'C':
      return category == ProductCategory.snacksBars || category == ProductCategory.chips;
    case 'D':
      return category == ProductCategory.sweetsCookies;
    case 'E':
      return category == ProductCategory.knabberMints;
    case 'F':
      return category == ProductCategory.fitness || category == ProductCategory.knabberMints;
    default:
      return false;
  }
}