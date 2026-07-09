import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vendingSessionProvider);
    final productAsync = ref.watch(productControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adminbereich')
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 320,
              child: _CoinInventoryPanel(session: session)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: productAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text('Fehler beim Laden: $error')
                ),
                data: (products) {
                  return _ProductStockPanel(products: products);
                }
              )
            )
          ]
        )
      )
    );
  }
}

class _CoinInventoryPanel extends ConsumerWidget {
  const _CoinInventoryPanel({required this.session});

  final VendingSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Münzspeicher', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...coinDenominationsCents.map((coin) {
              final quantity = session.coinInventory[coin] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(formatCents(coin))
                    ),
                    Text('$quantity Stk.'),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(vendingSessionProvider.notifier).addCoinsToInventory(coin, 1);
                      },
                      child: const Text('+1')
                    )
                  ],
                )
              );
            })
          ],
        )
      )
    );
  }
}

class _ProductStockPanel extends ConsumerWidget {
  const _ProductStockPanel({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Produktbestand', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final product = products[index];

                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text('Slot ${product.rowLabel}${product.columnNumber} | ${formatCents(product.priceCents)}'),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Bestand: ${product.stockQuantity}'),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(productControllerProvider.notifier).decreaseStockForAdmin(product);
                          },
                          child: const Text('-1')
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(productControllerProvider.notifier).increaseStock(product);
                          },
                          child: Text('+1'),
                        )
                      ]
                    )
                  );
                  
                }
              ),
            )
          ],
        )
      )
    );
  }
}