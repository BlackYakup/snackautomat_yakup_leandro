import 'dart:io';

import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_model_preview.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/local_file_cache.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/product_catalog_assets.dart';

const productIconOptions = <String, IconData>{
  'local_drink': Icons.local_drink,
  'fastfood': Icons.fastfood,
  'cookie': Icons.cookie,
  'icecream': Icons.icecream,
  'fitness_center': Icons.fitness_center,
  'water_drop': Icons.water_drop,
  'lunch_dining': Icons.lunch_dining,
  'cake': Icons.cake,
  'coffee': Icons.coffee,
  'sports_bar': Icons.sports_bar,
};

IconData productIconForKey(String? iconKey) {
  return productIconOptions[iconKey] ?? Icons.inventory_2;
}

class ProductVisualAvatar extends StatelessWidget {
  const ProductVisualAvatar({
    required this.product,
    this.size = 48,
    this.preferModelPreview = false,
    super.key,
  });

  final Product product;
  final double size;

  /// Wenn wahr und ein Modellpfad existiert: echtes 3D darstellen (nur einzeln nutzen).
  final bool preferModelPreview;

  @override
  Widget build(BuildContext context) {
    final modelPath = product.modelPath;
    final hasModel = modelPath != null && modelPath.isNotEmpty;

    if (preferModelPreview && hasModel) {
      return ProductModelPreview(
        modelPath: modelPath,
        size: size,
        selectedPart: product.modelPart,
      );
    }

    final imagePath = product.imagePath;
    final hasAssetImage = isBundleAssetPath(imagePath);
    final hasFileImage = imagePath != null &&
        imagePath.isNotEmpty &&
        !hasAssetImage &&
        LocalFileCache.exists(imagePath);

    if (hasAssetImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Image.asset(
              imagePath!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _iconFallback(context),
            ),
            if (hasModel)
              Positioned(
                right: 4,
                bottom: 4,
                child: ProductModelBadge(size: size * 0.28),
              ),
          ],
        ),
      );
    }

    if (hasFileImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Image.file(
              File(imagePath),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: size >= 120 ? 240 : 96,
            ),
            if (hasModel)
              Positioned(
                right: 4,
                bottom: 4,
                child: ProductModelBadge(size: size * 0.28),
              ),
          ],
        ),
      );
    }

    if (hasModel) {
      return ProductModelBadge(size: size);
    }

    return _iconFallback(context);
  }

  Widget _iconFallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        productIconForKey(product.iconKey),
        size: size * 0.55,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

String productCategoryLabel(ProductCategory category) {
  switch (category) {
    case ProductCategory.drinks:
      return 'Getränke';
    case ProductCategory.snacksBars:
      return 'Snacks & Riegel';
    case ProductCategory.chips:
      return 'Chips';
    case ProductCategory.sweetsCookies:
      return 'Süßes & Kekse';
    case ProductCategory.knabberMints:
      return 'Knabber & Mints';
    case ProductCategory.fitness:
      return 'Fitness';
  }
}
