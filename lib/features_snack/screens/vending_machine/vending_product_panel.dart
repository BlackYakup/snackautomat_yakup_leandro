import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_visual.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';

class VendingProductPanel extends ConsumerWidget {
  const VendingProductPanel({super.key});

  static const rowLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productControllerProvider);
    final selectedProduct = ref.watch(
      vendingSessionProvider.select((session) => session.selectedProduct),
    );
    final outputProductName = ref.watch(
      vendingSessionProvider.select((session) => session.outputProductName),
    );

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Fehler beim Laden: $error')),
      data: (products) {
        return Column(
          children: [
            Expanded(
              child: _ProductArea(
                products: products,
                selectedProduct: selectedProduct,
              ),
            ),
            const SizedBox(height: 8),
            _ProductOutput(outputProductName: outputProductName),
          ],
        );
      },
    );
  }
}

class _ProductArea extends StatelessWidget {
  const _ProductArea({
    required this.products,
    required this.selectedProduct,
  });

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
                children: VendingProductPanel.rowLabels.map((rowLabel) {
                  return Expanded(
                    child: _ProductRow(
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

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.rowLabel,
    required this.products,
    required this.selectedProduct,
  });

  final String rowLabel;
  final List<Product> products;
  final Product? selectedProduct;

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
            child: _EmptySlot(slotLabel: '$rowLabel$column'),
          ),
        );
        column += 1;
      } else {
        children.add(
          Expanded(
            flex: product.slotWidth,
            child: _ProductTile(
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

  Product? _productStartingAt(String rowLabel, int columnNumber) {
    for (final product in products) {
      if (product.rowLabel.toUpperCase() == rowLabel &&
          product.columnNumber == columnNumber) {
        return product;
      }
    }

    return null;
  }

  bool _isSameProduct(Product product, Product? selectedProduct) {
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

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.isSelected,
  });

  final Product product;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isSoldOut = product.isSoldOut;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSoldOut
              ? Colors.grey.shade300
              : isSelected
                  ? Colors.lightBlue.shade100
                  : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Opacity(
          opacity: isSoldOut ? 0.45 : 1,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: product.slotWidth == 2 ? 170 : 90,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductVisualAvatar(product: product, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      '${product.rowLabel}${product.columnNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      formatCents(product.priceCents),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Bestand: ${product.stockQuantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.slotLabel});

  final String slotLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              slotLabel,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductOutput extends StatelessWidget {
  const _ProductOutput({required this.outputProductName});

  final String? outputProductName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 64,
        width: double.infinity,
        child: ListTile(
          title: const Text('Produktausgabe'),
          subtitle: Text(outputProductName ?? 'Leer'),
        ),
      ),
    );
  }
}
