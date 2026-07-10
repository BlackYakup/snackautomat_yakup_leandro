import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_screen.dart';

class VendingMachineScreen extends ConsumerWidget {
  const VendingMachineScreen({super.key});

  static const rowLabels = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productControllerProvider);
    final session = ref.watch(vendingSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snackautomat'),
        actions: [
          IconButton(
            tooltip: 'Admin',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Fehler beim Laden: $error'),
        ),
        data: (products) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  constraints.maxWidth < 920 ? 920.0 : constraints.maxWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              Expanded(
                                child: _ProductArea(
                                  products: products,
                                  selectedProduct: session.selectedProduct,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _ProductOutput(session: session),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 360,
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: _ControlPanel(session: session),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _ChangeOutput(session: session),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductArea extends ConsumerWidget {
  const _ProductArea({
    required this.products,
    required this.selectedProduct,
  });

  final List<Product> products;
  final Product? selectedProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                children: VendingMachineScreen.rowLabels.map((rowLabel) {
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

class _ProductRow extends ConsumerWidget {
  const _ProductRow({
    required this.rowLabel,
    required this.products,
    required this.selectedProduct,
  });

  final String rowLabel;
  final List<Product> products;
  final Product? selectedProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.session});

  final VendingSessionState session;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DigitalDisplay(session: session),
        const SizedBox(height: 8),
        const _InputAndCoinPanel()
      ],
    );
  }
}

class _InputAndCoinPanel extends StatelessWidget {
  const _InputAndCoinPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 168,
                    child: _SlotKeypad()
                  ),
                  VerticalDivider(width: 20, thickness: 1),
                  Expanded(
                    child: _CoinSlot(),
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),
            const _ActionButtons()
          ],
        )
      ),
    );
  }
}

class _DigitalDisplay extends StatelessWidget {
  const _DigitalDisplay({required this.session});

  final VendingSessionState session;

  @override
  Widget build(BuildContext context) {
    final product = session.selectedProduct;
    final slotText = session.currentSlotInput.isNotEmpty
        ? session.currentSlotInput
        : session.selectedSlotCode ?? '-';
    final expectedChange = session.expectedChangeCents;

    return Card(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 15,
            fontFamily: 'monospace',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'DISPLAY',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(color: Colors.greenAccent),
              Text('Slot: $slotText'),
              Text('Produkt: ${product?.name ?? '-'}'),
              Text('Preis: ${product == null ? '-' : formatCents(product.priceCents)}'),
              Text('Eingeworfen: ${formatCents(session.insertedAmountCents)}'),
              Text('Fehlt: ${product == null ? '-' : formatCents(session.missingAmountCents)}'),
              Text('Wechselgeld: ${expectedChange == null ? '-' : formatCents(expectedChange)}'),
              const SizedBox(height: 8),
              Text('Status: ${session.statusMessage}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinSlot extends ConsumerWidget {
  const _CoinSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Münzschlitz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Akzeptierte Münzen'),
        ...coinDenominationsCents.map((coin) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SizedBox(
              height: 34,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(vendingSessionProvider.notifier).insertCoin(coin);
                },
                child: Text(formatCents(coin))
              )
            ),
          );
        })
      ],
    );
  }
}

class _SlotKeypad extends ConsumerWidget {
  const _SlotKeypad();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vendingSessionProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Tastenfeld', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildKeyRow(['A', 'B', 'C'], notifier),
        _buildKeyRow(['D', 'E', 'F'], notifier),
        _buildKeyRow(['1', '2', '3'], notifier),
        _buildKeyRow(['4', '5', '6'], notifier),
        _buildKeyRow(['7', '8', '9'], notifier),
        _buildKeyRow(['', '0', ''], notifier),
        SizedBox(
          height: 24,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade800,
              backgroundColor: Colors.red.shade50,
              side: BorderSide(color: Colors.red.shade300),
            ),
            onPressed: notifier.clearSlotInput,
            child: const Text('Leeren'),
          )
        )
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys, VendingSessionNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: keys.map((key) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: key.isEmpty
                ? const SizedBox(height: 38)
                : _KeyButton(
                  label: key,
                  onPressed: () => notifier.pressSlotKey(key)
                )
            )
          );
        }).toList()
      )
    );
  }
}



class _KeyButton extends StatelessWidget {
  const _KeyButton ({
    required this.label,
    required this.onPressed
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey.shade100,
                  Colors.grey.shade300,
                ],
              ),
              border: Border.all(color: Colors.grey.shade500),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              ref.read(vendingSessionProvider.notifier).buySelectedProduct();
            },
            child: const Text('Kaufen')
          )
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              ref.read(vendingSessionProvider.notifier).cancelPurchase();
            },
            child: const Text('Abbrechen')
          )
        )
      ],
    );
  }
}

class _ProductOutput extends StatelessWidget {
  const _ProductOutput({required this.session});

  final VendingSessionState session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 64,
        width: double.infinity,
        child: ListTile(
          title: const Text('Produktausgabe'),
          subtitle: Text(session.outputProductName ?? 'Leer'),
        ),
      ),
    );
  }
}

class _ChangeOutput extends StatelessWidget {
  const _ChangeOutput({required this.session});

  final VendingSessionState session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        child: ListTile(
          title: const Text('Wechselgeldausgabe'),
          subtitle: Text(_formatCoinMap(session.outputChange)),
        ),
      ),
    );
  }

  String _formatCoinMap(Map<int, int> coins) {
    if (coins.isEmpty) {
      return 'Leer';
    }

    final entries = coins.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return entries
        .map((entry) => '${entry.value} x ${formatCents(entry.key)}')
        .join(', ');
  }
}
