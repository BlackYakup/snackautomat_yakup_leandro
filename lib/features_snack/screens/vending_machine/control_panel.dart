import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/digital_display.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/input_and_coin_panel.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.session,
  });

  final VendingSessionState session;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DigitalDisplay(session: session),
        const SizedBox(height: 8),
        const InputAndCoinPanel(),
      ],
    );
  }
}
