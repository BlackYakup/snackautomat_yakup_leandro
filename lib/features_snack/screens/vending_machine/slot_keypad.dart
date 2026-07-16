import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/key_button.dart';

class SlotKeypad extends ConsumerWidget {
  const SlotKeypad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vendingSessionProvider.notifier);
    final inputEnabled = ref.watch(
      vendingSessionProvider.select(
        (session) => session.canAcceptCustomerInput,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tastenfeld',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildKeyRow(['A', 'B', 'C'], notifier, inputEnabled),
        _buildKeyRow(['D', 'E', 'F'], notifier, inputEnabled),
        _buildKeyRow(['1', '2', '3'], notifier, inputEnabled),
        _buildKeyRow(['4', '5', '6'], notifier, inputEnabled),
        _buildKeyRow(['7', '8', '9'], notifier, inputEnabled),
        _buildKeyRow(['', '0', ''], notifier, inputEnabled),
        KeyButton.destructive(
          label: 'Leeren',
          onPressed: inputEnabled ? notifier.clearSlotInput : null,
        ),
      ],
    );
  }

  Widget _buildKeyRow(
    List<String> keys,
    VendingSessionNotifier notifier,
    bool inputEnabled,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: keys.map((key) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: key.isEmpty
                  ? const SizedBox(height: 40)
                  : KeyButton(
                      label: key,
                      onPressed: inputEnabled
                          ? () => notifier.pressSlotKey(key)
                          : null,
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
