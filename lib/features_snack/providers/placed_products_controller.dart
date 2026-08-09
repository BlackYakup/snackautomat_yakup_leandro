part of 'provider_library.dart';

class PlacedProductsController extends AsyncNotifier<List<PlacedProduct>> {
  @override
  Future<List<PlacedProduct>> build() async {
    // Abhängigkeit vom Katalog, damit die Befüllung zuerst läuft.
    await ref.watch(productControllerProvider.future);
    try {
      final repository = await ref.watch(productRepositoryProvider.future);
      return repository.getPlacedProducts();
    } catch (error) {
      debugPrint('PlacedProductsController: $error');
      return const [];
    }
  }

  Future<void> reload() async {
    try {
      final repository = await ref.read(productRepositoryProvider.future);
      state = AsyncData(await repository.getPlacedProducts());
    } catch (error) {
      debugPrint('PlacedProductsController reload: $error');
    }
  }

  Future<void> increaseStock(PlacedProduct placed) async {
    await _changeStock(placed, 1);
  }

  Future<void> increaseStockBy(PlacedProduct placed, int amount) async {
    if (amount <= 0) return;
    final target = (placed.stockQuantity + amount).clamp(0, placed.maxCapacity);
    final diff = target - placed.stockQuantity;
    if (diff > 0) await _changeStock(placed, diff);
  }

  Future<void> refillToMax(PlacedProduct placed) async {
    await _setStock(placed, placed.maxCapacity);
  }

  Future<void> setStockQuantity(PlacedProduct placed, int stockQuantity) async {
    await _setStock(placed, stockQuantity.clamp(0, placed.maxCapacity));
  }

  Future<void> decreaseStockForAdmin(PlacedProduct placed) async {
    await _changeStock(placed, -1);
  }

  Future<bool> decreaseStockAfterPurchase(PlacedProduct placed) async {
    final list = state.value ?? const <PlacedProduct>[];
    final index = _indexOf(list, placed);
    if (index == -1 || list[index].stockQuantity <= 0) return false;

    final updated = list[index].copyWithStock(list[index].stockQuantity - 1);
    final next = [...list];
    next[index] = updated;
    state = AsyncData(next);
    await _persist(updated);
    return true;
  }

  Future<void> _changeStock(PlacedProduct placed, int difference) async {
    final list = state.value ?? const <PlacedProduct>[];
    final index = _indexOf(list, placed);
    if (index == -1) return;
    final newStock = list[index].stockQuantity + difference;
    if (newStock < 0 || newStock > list[index].maxCapacity) return;
    final updated = list[index].copyWithStock(newStock);
    final next = [...list];
    next[index] = updated;
    state = AsyncData(next);
    await _persist(updated);
  }

  Future<void> _setStock(PlacedProduct placed, int newStock) async {
    final list = state.value ?? const <PlacedProduct>[];
    final index = _indexOf(list, placed);
    if (index == -1) return;
    if (newStock < 0 || newStock > list[index].maxCapacity) return;
    final updated = list[index].copyWithStock(newStock);
    final next = [...list];
    next[index] = updated;
    state = AsyncData(next);
    await _persist(updated);
  }

  Future<void> _persist(PlacedProduct placed) async {
    final slotId = placed.slotId;
    if (slotId == null) return;
    try {
      final repository = await ref.read(productRepositoryProvider.future);
      await repository.updateSlotStock(
        slotId: slotId,
        stockQuantity: placed.stockQuantity,
      );
    } catch (error) {
      debugPrint('Slot-Bestand speichern fehlgeschlagen: $error');
    }
  }

  int _indexOf(List<PlacedProduct> list, PlacedProduct target) {
    return list.indexWhere((entry) {
      if (entry.slotId != null && target.slotId != null) {
        return entry.slotId == target.slotId;
      }
      return entry.rowLabel == target.rowLabel &&
          entry.columnNumber == target.columnNumber;
    });
  }
}

