import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/coin_slot.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/slot_keypad.dart';

class InputAndCoinPanel extends StatelessWidget {
  const InputAndCoinPanel({super.key});

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
                    child: SlotKeypad(),
                  ),
                  VerticalDivider(width: 20, thickness: 1),
                  Expanded(
                    child: CoinSlot(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
