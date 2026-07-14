import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';

class VendingInputPanel extends ConsumerWidget {
  const VendingInputPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Card(
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
                            child: _SlotKeypad(),
                          ),
                          VerticalDivider(width: 20, thickness: 1),
                          Expanded(
                            child: _CoinSlot(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _ActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _ChangeOutput(),
      ],
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
        const Text(
          'Münzschlitz',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
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
                child: Text(formatCents(coin)),
              ),
            ),
          );
        }),
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
        const Text(
          'Tastenfeld',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
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
          ),
        ),
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
                      onPressed: () => notifier.pressSlotKey(key),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onPressed,
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
            child: const Text('Kaufen'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              ref.read(vendingSessionProvider.notifier).cancelPurchase();
            },
            child: const Text('Abbrechen'),
          ),
        ),
      ],
    );
  }
}

class _ChangeOutput extends ConsumerWidget {
  const _ChangeOutput();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vendingSessionProvider);

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
