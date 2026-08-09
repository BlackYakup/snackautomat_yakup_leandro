/// Doppelslots E/F: Automaten-Schilder sind 1–5, physisch 10 Spalten (Paare).
///
/// Schild / Tastatur | Motoren      | Produkt-Mesh
/// ----------------- | ------------ | -------------
/// E1 / F1           | 1 + 2        | Product_E01 / F01
/// E2 / F2           | 3 + 4        | Product_E03 / F03
/// E3 / F3           | 5 + 6        | Product_E05 / F05
/// E4 / F4           | 7 + 8        | Product_E07 / F07
/// E5 / F5           | 9 + 10       | Product_E09 / F09
///
/// E6–E10 / F6–F10 existieren **nicht** als Kunden-Auswahl (Doppelslot).
library;

bool isDoubleSlotRow(String rowLabel) {
  final row = rowLabel.toUpperCase();
  return row == 'E' || row == 'F';
}

/// Kunden-Tastatur: A–D → Spalten 1–10; E/F → nur Schild 1–5.
bool isValidUserSlotSelection({
  required String rowLabel,
  required int columnNumber,
}) {
  final row = rowLabel.toUpperCase();
  if (!const {'A', 'B', 'C', 'D', 'E', 'F'}.contains(row)) {
    return false;
  }
  if (isDoubleSlotRow(row)) {
    return columnNumber >= 1 && columnNumber <= 5;
  }
  return columnNumber >= 1 && columnNumber <= 10;
}

/// Tastatur 1–5 (Schild) → physische Startspalte 1,3,5,7,9.
///
/// Nur für bereits gültige E/F-Schildnummern (1–5) oder interne
/// physische Startspalten (ungerade 1…9). Kunden-Eingaben &gt; 5 vorher
/// mit [isValidUserSlotSelection] ablehnen.
int mapDoubleSlotInputToPhysicalStart(int columnNumber) {
  if (columnNumber >= 1 && columnNumber <= 5) {
    return columnNumber * 2 - 1;
  }
  if (columnNumber >= 1 && columnNumber <= 10 && columnNumber.isOdd) {
    return columnNumber;
  }
  if (columnNumber >= 2 && columnNumber <= 10 && columnNumber.isEven) {
    return columnNumber - 1;
  }
  return columnNumber.clamp(1, 9);
}

/// Physische Startspalte (1,3,5,7,9) → Schild-Nummer 1–5.
int physicalStartToDoubleSlotLabel(int physicalStart) {
  final start = physicalStart.isOdd ? physicalStart : physicalStart - 1;
  return ((start + 1) ~/ 2).clamp(1, 5);
}

/// Beide Motor-/Spiral-Spalten für einen E/F-Slot.
List<int> spiralColumnsForDoubleSlot({
  required String rowLabel,
  required int columnNumber,
}) {
  if (!isDoubleSlotRow(rowLabel)) {
    return [columnNumber];
  }
  final start = mapDoubleSlotInputToPhysicalStart(columnNumber);
  return [start, start + 1];
}

/// Mesh-Spalte für Product_XYY (immer ungerade Startspalte auf E/F).
int productMeshColumnForSlot({
  required String rowLabel,
  required int columnNumber,
}) {
  if (!isDoubleSlotRow(rowLabel)) {
    return columnNumber;
  }
  return mapDoubleSlotInputToPhysicalStart(columnNumber);
}

/// Anzeige-Code wie auf dem Automaten-Schild: E/F → `F1`…`F5`.
String displaySlotCode({
  required String rowLabel,
  required int columnNumber,
}) {
  final row = rowLabel.toUpperCase();
  if (!isDoubleSlotRow(row)) {
    return '$row$columnNumber';
  }
  final start = columnNumber.isOdd ? columnNumber : columnNumber - 1;
  return '$row${physicalStartToDoubleSlotLabel(start)}';
}
