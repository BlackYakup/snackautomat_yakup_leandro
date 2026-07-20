import 'dart:io';

import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_model_preview.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/local_file_cache.dart';

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
    super.key,
  });

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imagePath = product.imagePath;
    final hasImage = imagePath != null &&
        imagePath.isNotEmpty &&
        LocalFileCache.exists(imagePath);
    final hasModelPath =
        product.modelPath != null && product.modelPath!.isNotEmpty;

    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(imagePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: size >= 120 ? 240 : 96,
        ),
      );
    }

    if (hasModelPath) {
      return ProductModelBadge(size: size);
    }

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
