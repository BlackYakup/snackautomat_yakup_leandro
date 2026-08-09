import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/slot_code_parser.dart';

void main() {
  group('SlotCode.tryParse', () {
    for (final input in ['A1', 'A10', 'C4', 'F10']) {
      test('$input ist gültig', () {
        final result = SlotCode.tryParse(input);

        expect(result, isNotNull);
        expect(result!.code, input);
      });
    }

    for (final input in ['', 'A', 'A0', 'A11', 'G1', 'AA', '1A']) {
      test('"$input" ist ungültig', () {
        expect(SlotCode.tryParse(input), isNull);
      });
    }

    test('Kleinbuchstaben werden normalisiert', () {
      final result = SlotCode.tryParse('c4');

      expect(result?.code, 'C4');
    });

    test('äußere Leerzeichen werden entfernt', () {
      final result = SlotCode.tryParse('  C4  ');

      expect(result?.code, 'C4');
    });
  });
}
