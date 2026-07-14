import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';

class VendingHudDisplay extends ConsumerWidget {
  const VendingHudDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vendingSessionProvider);
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
              Text(
                'Preis: ${product == null ? '-' : formatCents(product.priceCents)}',
              ),
              Text('Eingeworfen: ${formatCents(session.insertedAmountCents)}'),
              Text(
                'Fehlt: ${product == null ? '-' : formatCents(session.missingAmountCents)}',
              ),
              Text(
                'Wechselgeld: ${expectedChange == null ? '-' : formatCents(expectedChange)}',
              ),
              const SizedBox(height: 8),
              Text('Status: ${session.statusMessage}'),
            ],
          ),
        ),
      ),
    );
  }
}
