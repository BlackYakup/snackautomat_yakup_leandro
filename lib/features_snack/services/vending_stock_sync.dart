import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/double_slot_layout.dart';

const _vendingRows = ['A', 'B', 'C', 'D', 'E', 'F'];
const _vendingColumns = 10;

/// Slot-Code → Bestand für 3D-Mesh-Sync (`A1` → `Product_A01_s*`).
///
/// Enthält **alle** Slots A–F×1–10 (fehlende = 0), damit unsichtbare Meshes
/// nicht als GLB-Standard sichtbar bleiben.
///
/// E/F-Bestand liegt unter dem physischen Startcode (`F1`, `F3`, …) — so wie
/// die Mesh-Namen `Product_F01` / `Product_F03`.
Map<String, int> stockBySlotFromPlaced(List<PlacedProduct> placed) {
  final map = <String, int>{};
  for (final row in _vendingRows) {
    for (var col = 1; col <= _vendingColumns; col++) {
      map['$row$col'] = 0;
    }
  }
  for (final p in placed) {
    final row = p.rowLabel.toUpperCase();
    // DB speichert physische Startspalte (1,3,5,7,9) — nicht nochmal zuordnen.
    final start = isDoubleSlotRow(row)
        ? (p.columnNumber.isOdd ? p.columnNumber : p.columnNumber - 1)
        : p.columnNumber;
    map['$row$start'] = p.stockQuantity;
  }
  return map;
}

/// Normalisiert Slot-Codes wie `A1` / `a01` → `A1`.
/// E/F: Eingabe `F2` (Schild) → physischer Start `F3`.
String normalizeSlotCode(String raw) {
  final m = RegExp(r'^([A-Fa-f])0*([1-9]\d?|10)$').firstMatch(raw.trim());
  if (m == null) return raw.trim().toUpperCase();
  final row = m.group(1)!.toUpperCase();
  var col = int.parse(m.group(2)!);
  if (isDoubleSlotRow(row)) {
    col = mapDoubleSlotInputToPhysicalStart(col);
  }
  return '$row$col';
}

/// Mesh-Präfix ohne Stapel: `Product_A01` für Slot `A1`.
/// E/F: `F2` (Schild) → `Product_F03`.
String productMeshPrefixForSlot(String slotCode) {
  final n = normalizeSlotCode(slotCode);
  final m = RegExp(r'^([A-F])(\d{1,2})$').firstMatch(n);
  if (m == null) return 'Product_$n';
  final row = m.group(1)!;
  final col = int.parse(m.group(2)!).toString().padLeft(2, '0');
  return 'Product_$row$col';
}
