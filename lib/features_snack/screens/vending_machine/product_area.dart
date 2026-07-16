import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/product_row.dart';

class ProductArea extends StatelessWidget {
  const ProductArea({
    super.key,
    required this.products,
    required this.selectedProduct,
  });

  static const _rowLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

  final List<Product> products;
  final Product? selectedProduct;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              'Produkte',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                children: _rowLabels.map((rowLabel) {
                  return Expanded(
                    child: ProductRow(
                      rowLabel: rowLabel,
                      products: products,
                      selectedProduct: selectedProduct,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
