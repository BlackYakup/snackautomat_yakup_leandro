import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_slot.dart';

const productCatalogAssetPath = 'assets/products/catalog.json';

bool isBundleAssetPath(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }
  return path.startsWith('assets/');
}

String? iconKeyForCategory(ProductCategory category) {
  switch (category) {
    case ProductCategory.drinks:
      return 'local_drink';
    case ProductCategory.snacksBars:
      return 'fastfood';
    case ProductCategory.chips:
      return 'lunch_dining';
    case ProductCategory.sweetsCookies:
      return 'cookie';
    case ProductCategory.knabberMints:
      return 'icecream';
    case ProductCategory.fitness:
      return 'fitness_center';
  }
}

class CatalogSeedData {
  const CatalogSeedData({
    required this.products,
    required this.slotAssignments,
  });

  /// Eindeutige Katalogprodukte (nach Slug/Name+Modell).
  final List<Product> products;

  /// Slot-Belegungen mit Verweis auf den Produktindex in [products].
  final List<({int productIndex, ProductSlot slot})> slotAssignments;
}

class ProductCatalogAssets {
  const ProductCatalogAssets._();

  static Future<CatalogSeedData> loadSeedData() async {
    final raw = await rootBundle.loadString(productCatalogAssetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const CatalogSeedData(products: [], slotAssignments: []);
    }

    final entries = decoded['products'];
    if (entries is! List) {
      return const CatalogSeedData(products: [], slotAssignments: []);
    }

    final products = <Product>[];
    final indexByKey = <String, int>{};
    final assignments = <({int productIndex, ProductSlot slot})>[];

    for (final entry in entries) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final slug = map['slug'] as String? ?? map['name'] as String? ?? 'produkt';
      final categoryValue = map['category'] as String? ?? 'snacks_bars';
      final category = ProductCategory.fromDbValue(categoryValue);
      final modelAsset = map['model_asset'] as String?;
      final imageAsset = map['image_asset'] as String?;
      final hasModel =
          map['has_model'] == true && modelAsset != null && modelAsset.isNotEmpty;
      final hasImage =
          map['has_image'] == true && imageAsset != null && imageAsset.isNotEmpty;
      final slotWidth = (map['slot_width'] as num?)?.toInt() ?? 1;
      final maxCapacity = (map['max_capacity'] as num?)?.toInt() ?? 5;
      final stock = (map['stock_quantity'] as num?)?.toInt() ?? 5;
      final name = map['name'] as String? ?? slug;
      final priceCents = (map['price_cents'] as num?)?.toInt() ?? 150;

      final key = '$slug|$modelAsset|$priceCents';
      var productIndex = indexByKey[key];
      if (productIndex == null) {
        productIndex = products.length;
        indexByKey[key] = productIndex;
        products.add(
          Product(
            name: name,
            priceCents: priceCents,
            maxCapacity: maxCapacity,
            category: category,
            slotWidth: slotWidth,
            modelPath: hasModel ? modelAsset : null,
            imagePath: hasImage ? imageAsset : null,
            iconKey: iconKeyForCategory(category),
          ),
        );
      }

      final rowLabel = (map['row_label'] as String? ?? 'A').toUpperCase();
      final columnNumber = (map['column_number'] as num?)?.toInt() ?? 1;
      assignments.add((
        productIndex: productIndex,
        slot: ProductSlot(
          productId: -1, // filled after insert
          rowLabel: rowLabel,
          columnNumber: columnNumber,
          stockQuantity: stock,
          maxCapacity: maxCapacity,
        ),
      ));
    }

    return CatalogSeedData(products: products, slotAssignments: assignments);
  }

  static Future<List<Product>> loadProducts() async {
    final data = await loadSeedData();
    return data.products;
  }
}
