import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/empty_slot.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/product_tile.dart';

class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.rowLabel,
    required this.products,
    required this.selectedProduct,
  });

  final String rowLabel;
  final List<PlacedProduct> products;
  final PlacedProduct? selectedProduct;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      SizedBox(
        width: 32,
        child: Center(
          child: Text(
            rowLabel,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ];

    var column = 1;

    while (column <= 10) {
      final product = _productStartingAt(rowLabel, column);

      if (product == null) {
        children.add(
          Expanded(
            child: EmptySlot(slotLabel: '$rowLabel$column'),
          ),
        );
        column += 1;
      } else {
        children.add(
          Expanded(
            flex: product.slotWidth,
            child: ProductTile(
              product: product,
              isSelected: _isSameProduct(product, selectedProduct),
            ),
          ),
        );
        column += product.slotWidth;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: children),
    );
  }

  PlacedProduct? _productStartingAt(String rowLabel, int columnNumber) {
    for (final product in products) {
      if (product.rowLabel.toUpperCase() == rowLabel &&
          product.columnNumber == columnNumber) {
        return product;
      }
    }

    return null;
  }

  bool _isSameProduct(PlacedProduct product, PlacedProduct? selectedProduct) {
    if (selectedProduct == null) {
      return false;
    }

    if (product.id != null && selectedProduct.id != null) {
      return product.id == selectedProduct.id;
    }

    return product.rowLabel == selectedProduct.rowLabel &&
        product.columnNumber == selectedProduct.columnNumber;
  }
}
