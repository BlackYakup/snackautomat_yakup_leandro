part of 'provider_library.dart';

mixin _VendingSessionHelpers on _VendingSessionFields {
  bool _isRowKey(String key) {
    return ['A', 'B', 'C', 'D', 'E', 'F'].contains(key);
  }

  bool _isDigitKey(String key) {
    return RegExp(r'^[0-9]$').hasMatch(key);
  }

  bool _isSelectedSoldOut() {
    final product = state.selectedProduct;
    if (product == null) return true;
    return _findCurrentProduct(product).isSoldOut;
  }

  PlacedProduct? _findPlacedAtSlot({
    required List<PlacedProduct> placed,
    required String rowLabel,
    required int columnNumber,
  }) {
    for (final entry in placed) {
      final start = entry.columnNumber;
      final end = entry.columnNumber + entry.slotWidth - 1;
      if (entry.rowLabel.toUpperCase() == rowLabel &&
          columnNumber >= start &&
          columnNumber <= end) {
        return entry;
      }
    }
    return null;
  }

  PlacedProduct _findCurrentProduct(PlacedProduct selectedProduct) {
    final placed =
        ref.read(placedProductsProvider).value ?? const <PlacedProduct>[];
    final slotCode = state.selectedSlotCode;
    if (slotCode != null) {
      final parsed = SlotCode.tryParse(slotCode);
      if (parsed != null) {
        final lookupCol = isDoubleSlotRow(parsed.rowLabel)
            ? mapDoubleSlotInputToPhysicalStart(parsed.columnNumber)
            : parsed.columnNumber;
        final bySlot = _findPlacedAtSlot(
          placed: placed,
          rowLabel: parsed.rowLabel,
          columnNumber: lookupCol,
        );
        if (bySlot != null) return bySlot;
      }
    }

    for (final entry in placed) {
      if (entry.slotId != null &&
          selectedProduct.slotId != null &&
          entry.slotId == selectedProduct.slotId) {
        return entry;
      }
      if (entry.rowLabel == selectedProduct.rowLabel &&
          entry.columnNumber == selectedProduct.columnNumber) {
        return entry;
      }
    }
    return selectedProduct;
  }

  Map<int, int> _addCoinMaps(
    Map<int, int> coinInventory,
    Map<int, int> insertedCoins,
  ) {
    final result = Map<int, int>.from(coinInventory);

    for (final entry in insertedCoins.entries) {
      result[entry.key] = (result[entry.key] ?? 0) + entry.value;
    }

    return result;
  }

  Map<int, int> _subtractCoinMap(
    Map<int, int> coinInventory,
    Map<int, int> changeCoins,
  ) {
    final result = Map<int, int>.from(coinInventory);

    for (final entry in changeCoins.entries) {
      result[entry.key] = (result[entry.key] ?? 0) - entry.value;
    }

    return result;
  }
}
