import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/key_button.dart';

class SlotKeypad extends ConsumerWidget {
  const SlotKeypad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vendingSessionProvider.notifier);
    final slotKeysEnabled = ref.watch(
      vendingSessionProvider.select((session) => session.canUseSlotKeys),
    );
    final clearEnabled = ref.watch(
      vendingSessionProvider.select((session) => session.canClearSelection),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tastenfeld',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildKeyRow(['A', 'B', 'C'], notifier, slotKeysEnabled),
        _buildKeyRow(['D', 'E', 'F'], notifier, slotKeysEnabled),
        _buildKeyRow(['1', '2', '3'], notifier, slotKeysEnabled),
        _buildKeyRow(['4', '5', '6'], notifier, slotKeysEnabled),
        _buildKeyRow(['7', '8', '9'], notifier, slotKeysEnabled),
        _buildKeyRow(['', '0', ''], notifier, slotKeysEnabled),
        KeyButton.destructive(
          label: 'Leeren',
          onPressed: clearEnabled ? notifier.clearSlotInput : null,
        ),
      ],
    );
  }

  Widget _buildKeyRow(
    List<String> keys,
    VendingSessionNotifier notifier,
    bool slotKeysEnabled,
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
                      onPressed: slotKeysEnabled
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
