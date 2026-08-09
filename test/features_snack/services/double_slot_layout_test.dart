import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/double_slot_layout.dart';

void main() {
  group('isValidUserSlotSelection', () {
    test('A–D erlauben 1–10', () {
      expect(
        isValidUserSlotSelection(rowLabel: 'A', columnNumber: 10),
        isTrue,
      );
      expect(
        isValidUserSlotSelection(rowLabel: 'C', columnNumber: 6),
        isTrue,
      );
    });

    test('E/F nur Schild 1–5', () {
      for (final col in [1, 2, 3, 4, 5]) {
        expect(
          isValidUserSlotSelection(rowLabel: 'E', columnNumber: col),
          isTrue,
        );
        expect(
          isValidUserSlotSelection(rowLabel: 'F', columnNumber: col),
          isTrue,
        );
      }
      for (final col in [6, 7, 8, 9, 10]) {
        expect(
          isValidUserSlotSelection(rowLabel: 'E', columnNumber: col),
          isFalse,
        );
        expect(
          isValidUserSlotSelection(rowLabel: 'F', columnNumber: col),
          isFalse,
        );
      }
    });
  });

  group('mapDoubleSlotInputToPhysicalStart', () {
    test('Schild 1–5 → Motor-Start 1,3,5,7,9', () {
      expect(mapDoubleSlotInputToPhysicalStart(1), 1);
      expect(mapDoubleSlotInputToPhysicalStart(2), 3);
      expect(mapDoubleSlotInputToPhysicalStart(3), 5);
      expect(mapDoubleSlotInputToPhysicalStart(4), 7);
      expect(mapDoubleSlotInputToPhysicalStart(5), 9);
    });

    test('Interne physische Partner-Spalten werden auf Start gemappt', () {
      expect(mapDoubleSlotInputToPhysicalStart(6), 5);
      expect(mapDoubleSlotInputToPhysicalStart(10), 9);
      expect(mapDoubleSlotInputToPhysicalStart(9), 9);
    });
  });

  group('spiralColumnsForDoubleSlot', () {
    test('F1 → Motoren 1+2', () {
      expect(
        spiralColumnsForDoubleSlot(rowLabel: 'F', columnNumber: 1),
        [1, 2],
      );
    });

    test('F2 → Motoren 3+4', () {
      expect(
        spiralColumnsForDoubleSlot(rowLabel: 'F', columnNumber: 2),
        [3, 4],
      );
    });

    test('F5 → Motoren 9+10', () {
      expect(
        spiralColumnsForDoubleSlot(rowLabel: 'F', columnNumber: 5),
        [9, 10],
      );
    });

    test('A-Reihe bleibt Einzelslot', () {
      expect(
        spiralColumnsForDoubleSlot(rowLabel: 'A', columnNumber: 3),
        [3],
      );
    });
  });

  group('displaySlotCode', () {
    test('physisch F3 wird als F2 angezeigt', () {
      expect(
        displaySlotCode(rowLabel: 'F', columnNumber: 3),
        'F2',
      );
    });

    test('physisch E9 wird als E5 angezeigt', () {
      expect(
        displaySlotCode(rowLabel: 'E', columnNumber: 9),
        'E5',
      );
    });
  });
}
