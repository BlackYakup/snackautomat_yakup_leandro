import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/digital_display.dart';

void main() {
  testWidgets('Status-LED ist während der Zahlungsphase gelb (Neon)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DigitalDisplay(
            session: VendingSessionState(
              phase: VendingMachinePhase.paymentInProgress,
              currentSlotInput: 'C4',
              selectedSlotCode: 'C4',
              statusMessage: 'Bitte bezahlen.',
            ),
          ),
        ),
      ),
    );

    final led = tester.widget<Container>(
      find.byKey(const ValueKey('status-led')),
    );
    final decoration = led.decoration! as BoxDecoration;

    expect(decoration.color, const Color(0xFFFFD200));
  });

  testWidgets('Idle zeigt Produktwahl-Hinweis', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DigitalDisplay(
            session: VendingSessionState(
              phase: VendingMachinePhase.ready,
              statusMessage: 'Bitte Produktposition eingeben.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('WÄHLE DEIN PRODUKT'), findsOneWidget);
  });
}
