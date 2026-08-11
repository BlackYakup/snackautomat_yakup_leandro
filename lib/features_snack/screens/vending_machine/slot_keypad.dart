import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/key_button.dart';

/// Automaten-Tastenfeld: A–F, 0–9, X und OK — alle Tasten gleich groß und kompakt.
class SlotKeypad extends ConsumerWidget {
  const SlotKeypad({super.key, this.dense = false, this.showTitle = true});

  final bool dense;
  final bool showTitle;

  static const _rows = <List<({String label, KeyButtonStyle style})>>[
    [
      (label: 'A', style: KeyButtonStyle.letter),
      (label: 'B', style: KeyButtonStyle.letter),
      (label: 'C', style: KeyButtonStyle.letter),
    ],
    [
      (label: 'D', style: KeyButtonStyle.letter),
      (label: 'E', style: KeyButtonStyle.letter),
      (label: 'F', style: KeyButtonStyle.letter),
    ],
    [
      (label: '1', style: KeyButtonStyle.metal),
      (label: '2', style: KeyButtonStyle.metal),
      (label: '3', style: KeyButtonStyle.metal),
    ],
    [
      (label: '4', style: KeyButtonStyle.metal),
      (label: '5', style: KeyButtonStyle.metal),
      (label: '6', style: KeyButtonStyle.metal),
    ],
    [
      (label: '7', style: KeyButtonStyle.metal),
      (label: '8', style: KeyButtonStyle.metal),
      (label: '9', style: KeyButtonStyle.metal),
    ],
    [
      (label: 'X', style: KeyButtonStyle.cancel),
      (label: '0', style: KeyButtonStyle.metal),
      (label: 'OK', style: KeyButtonStyle.confirm),
    ],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vendingSessionProvider.notifier);
    final slotKeysEnabled = ref.watch(
      vendingSessionProvider.select((s) => s.canUseSlotKeys),
    );
    final clearEnabled = ref.watch(
      vendingSessionProvider.select((s) => s.canClearSelection),
    );
    final canConfirm = ref.watch(
      vendingSessionProvider.select(
        (s) =>
            s.selectedProduct != null &&
            (s.phase == VendingMachinePhase.paymentInProgress ||
                s.phase == VendingMachinePhase.ready),
      ),
    );
    final canCommitSlot = ref.watch(
      vendingSessionProvider.select(
        (s) =>
            s.canUseSlotKeys &&
            s.currentSlotInput.length >= 2 &&
            s.selectedProduct == null,
      ),
    );

    final keySize = dense ? 30.0 : 34.0;
    final gap = dense ? 5.0 : 6.0;
    final pad = dense ? 8.0 : 10.0;
    final gridWidth = keySize * 3 + gap * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle) ...[
          Text(
            'Tastenfeld',
            style: TextStyle(
              fontSize: dense ? 13 : 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: dense ? 4 : 6),
        ],
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFD8DCE2),
                  Color(0xFFB4BAC4),
                  Color(0xFF9AA1AC),
                ],
              ),
              border: Border.all(color: const Color(0xFF6E7580), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: SizedBox(
                width: gridWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var r = 0; r < _rows.length; r++) ...[
                      if (r > 0) SizedBox(height: gap),
                      _KeyRow(
                        keys: _rows[r],
                        gap: gap,
                        keySize: keySize,
                        onPressed: (label) {
                          if (label == 'X') {
                            if (clearEnabled) notifier.clearSlotInput();
                            return;
                          }
                          if (label == 'OK') {
                            if (canCommitSlot) {
                              notifier.processSlotInputAfterDelay();
                              return;
                            }
                            if (canConfirm) {
                              unawaited(notifier.buySelectedProduct());
                            }
                            return;
                          }
                          if (slotKeysEnabled) notifier.pressSlotKey(label);
                        },
                        isEnabled: (label) {
                          if (label == 'X') return clearEnabled;
                          if (label == 'OK') return canConfirm || canCommitSlot;
                          return slotKeysEnabled;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.keys,
    required this.gap,
    required this.keySize,
    required this.onPressed,
    required this.isEnabled,
  });

  final List<({String label, KeyButtonStyle style})> keys;
  final double gap;
  final double keySize;
  final void Function(String label) onPressed;
  final bool Function(String label) isEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          SizedBox(
            width: keySize,
            height: keySize,
            child: KeyButton(
              label: keys[i].label,
              style: keys[i].style,
              size: keySize,
              onPressed: isEnabled(keys[i].label)
                  ? () => onPressed(keys[i].label)
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}
