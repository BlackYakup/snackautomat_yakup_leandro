import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/constants/vending_coin_config.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_slot.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/coin_repository.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/db_creater.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/product_repository.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/transaction_repository.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/change_calculator.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/double_slot_layout.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/local_file_cache.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/product_asset_storage.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/product_catalog_assets.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/slot_code_parser.dart';
import 'package:sqflite/sqflite.dart';

export 'package:snackautomat_yakup_leandro/features_snack/constants/vending_coin_config.dart'
    show coinCassetteCapacity, coinDenominationsCents, formatCents;

enum VendingMachinePhase {
  ready,
  paymentInProgress,
  dispensing,
  thankYou,
  outOfService,
}

const purchaseResultDisplayDuration = Duration(seconds: 2);
const thankYouCharacterDuration = Duration(milliseconds: 45);
const thankYouHoldDuration = Duration(seconds: 2);
const changeDropDuration = Duration(milliseconds: 750);
/// Wartet nach der letzten Taste, damit z. B. A1 noch zu A10 werden kann.
const slotInputCommitDelay = Duration(seconds: 3);

const thankYouMessage =
    'Vielen Dank für Ihren Einkauf.\n'
    'Auf Wiedersehen';

final thankYouSequenceDuration = Duration(
  milliseconds:
      thankYouMessage.length * thankYouCharacterDuration.inMilliseconds +
      thankYouHoldDuration.inMilliseconds,
);

final databaseProvider = FutureProvider<Database>((ref) {
  return DbCreater.instance.database;
});

final productRepositoryProvider = FutureProvider<ProductRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  return ProductRepository(db);
});

final productControllerProvider =
    AsyncNotifierProvider<ProductController, List<Product>>(
      ProductController.new,
    );

final placedProductsProvider =
    AsyncNotifierProvider<PlacedProductsController, List<PlacedProduct>>(
      PlacedProductsController.new,
    );

final vendingSessionProvider =
    NotifierProvider<VendingSessionNotifier, VendingSessionState>(
      VendingSessionNotifier.new,
    );

class ProductController extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    try {
      final repository = await ref.watch(productRepositoryProvider.future);
      var products = await repository.getProducts();

      if (products.isEmpty) {
        await _seedCatalog(repository);
        products = await repository.getProducts();
      } else {
        await _ensureSlotsIfEmpty(repository, products);
        products = await repository.getProducts();
      }

      for (final product in products) {
        if (product.id != null && product.priceCents <= 0) {
          await repository.saveProduct(product.copyWith(priceCents: 150));
        }
      }
      products = await repository.getProducts();

      if (products.isNotEmpty) {
        return products;
      }
    } catch (error) {
      debugPrint('ProductController: Laden fehlgeschlagen: $error');
    }

    // Letzter Rückfall: in der DB befüllen, nicht nur im Speicher ohne Slots.
    try {
      final repository = await ref.read(productRepositoryProvider.future);
      await _seedCatalog(repository);
      final products = await repository.getProducts();
      if (products.isNotEmpty) return products;
    } catch (error) {
      debugPrint('ProductController: Fallback-Seed fehlgeschlagen: $error');
    }

    return _demoProducts;
  }

  /// Wenn Katalogprodukte existieren, aber keine Slots → Katalog-Slots nachziehen.
  Future<void> _ensureSlotsIfEmpty(
    ProductRepository repository,
    List<Product> products,
  ) async {
    final placed = await repository.getPlacedProducts();
    if (placed.isNotEmpty) return;

    debugPrint(
      'ProductController: ${products.length} Produkte ohne Slots — '
      'Slot-Belegung wird aus Katalog hergestellt.',
    );

    final seed = await ProductCatalogAssets.loadSeedData();
    if (seed.slotAssignments.isEmpty) {
      for (final demo in _demoPlacedProducts) {
        final match = products
            .where((p) => p.name == demo.product.name)
            .firstOrNull;
        if (match == null) continue;
        try {
          await repository.assignProductToSlot(
            product: match,
            rowLabel: demo.rowLabel,
            columnNumber: demo.columnNumber,
            stockQuantity: demo.stockQuantity,
            maxCapacity: demo.maxCapacity,
          );
        } catch (error) {
          debugPrint('Demo-Slot ${demo.slotCode}: $error');
        }
      }
      return;
    }

    final byName = <String, Product>{};
    for (final p in products) {
      byName.putIfAbsent(p.name, () => p);
    }

    for (final assignment in seed.slotAssignments) {
      final catalog = seed.products[assignment.productIndex];
      final match = byName[catalog.name];
      if (match == null) continue;
      try {
        await repository.assignProductToSlot(
          product: match,
          rowLabel: assignment.slot.rowLabel,
          columnNumber: assignment.slot.columnNumber,
          stockQuantity: assignment.slot.stockQuantity,
          maxCapacity: assignment.slot.maxCapacity,
        );
      } catch (error) {
        debugPrint('Slot-Repair ${assignment.slot.slotCode}: $error');
      }
    }
  }

  Future<void> _seedCatalog(ProductRepository repository) async {
    try {
      final seed = await ProductCatalogAssets.loadSeedData();
      if (seed.products.isEmpty) {
        for (final demo in _demoPlacedProducts) {
          await repository.saveProductAtSlot(
            PlacedProduct(
              product: demo.product.copyWith(id: null),
              slot: demo.slot.copyWith(id: null, productId: 0),
            ),
          );
        }
        return;
      }

      final insertedIds = <int>[];
      for (final product in seed.products) {
        final id = await repository.saveProduct(product.copyWith(id: null));
        insertedIds.add(id);
      }

      for (final assignment in seed.slotAssignments) {
        final productId = insertedIds[assignment.productIndex];
        final catalog = seed.products[assignment.productIndex];
        try {
          await repository.assignProductToSlot(
            product: catalog.copyWith(id: productId),
            rowLabel: assignment.slot.rowLabel,
            columnNumber: assignment.slot.columnNumber,
            stockQuantity: assignment.slot.stockQuantity,
            maxCapacity: assignment.slot.maxCapacity,
          );
        } catch (error) {
          debugPrint('Slot-Seed ${assignment.slot.slotCode}: $error');
        }
      }
    } catch (error) {
      debugPrint('ProductController: Katalog-Seed fehlgeschlagen: $error');
      for (final demo in _demoPlacedProducts) {
        try {
          await repository.saveProductAtSlot(
            PlacedProduct(
              product: demo.product.copyWith(id: null),
              slot: demo.slot.copyWith(id: null, productId: 0),
            ),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> saveProduct(Product product) async {
    final repository = await ref.read(productRepositoryProvider.future);
    await repository.saveProduct(product);
    LocalFileCache.invalidate(product.imagePath);
    LocalFileCache.invalidate(product.modelPath);
    await reloadProducts();
  }

  Future<void> savePlacedProduct(PlacedProduct placed) async {
    final repository = await ref.read(productRepositoryProvider.future);
    await repository.saveProductAtSlot(placed);
    LocalFileCache.invalidate(placed.imagePath);
    LocalFileCache.invalidate(placed.modelPath);
    await reloadProducts();
  }

  Future<void> deleteProduct(Product product) async {
    final productId = product.id;
    if (productId == null) {
      final products = state.value ?? const <Product>[];
      state = AsyncData(
        products.where((entry) => entry.name != product.name).toList(),
      );
      return;
    }

    try {
      final repository = await ref.read(productRepositoryProvider.future);
      await repository.deleteProduct(productId);
      await ProductAssetStorage.deleteAssetsForProduct(product);
      await reloadProducts();
    } catch (error) {
      debugPrint('ProductController: Löschen fehlgeschlagen: $error');
      await reloadProducts();
    }
  }

  Future<void> deletePlacedProduct(PlacedProduct placed) async {
    await deleteProduct(placed.product);
  }

  Future<void> reloadProducts() async {
    try {
      final repository = await ref.read(productRepositoryProvider.future);
      var products = await repository.getProducts();
      if (products.isEmpty) {
        await _seedCatalog(repository);
        products = await repository.getProducts();
      } else {
        await _ensureSlotsIfEmpty(repository, products);
        products = await repository.getProducts();
      }
      for (final product in products) {
        if (product.id != null && product.priceCents <= 0) {
          await repository.saveProduct(product.copyWith(priceCents: 150));
        }
      }
      products = await repository.getProducts();
      state = AsyncData(products.isEmpty ? _demoProducts : products);
      ref.invalidate(placedProductsProvider);
    } catch (error) {
      debugPrint('ProductController: Reload fehlgeschlagen: $error');
      state = AsyncData(state.value ?? _demoProducts);
    }
  }

  Future<void> assignToSlot({
    required Product product,
    required String rowLabel,
    required int columnNumber,
    required int stockQuantity,
    int? maxCapacity,
    int? existingSlotId,
    int? priceCents,
  }) async {
    final repository = await ref.read(productRepositoryProvider.future);
    var toPlace = product;
    if (priceCents != null && priceCents > 0) {
      toPlace = product.copyWith(priceCents: priceCents);
      await repository.saveProduct(toPlace);
    }
    await repository.assignProductToSlot(
      product: toPlace,
      rowLabel: rowLabel,
      columnNumber: columnNumber,
      stockQuantity: stockQuantity,
      maxCapacity: maxCapacity,
      existingSlotId: existingSlotId,
    );
    await reloadProducts();
  }

  Future<void> clearSlot(int slotId) async {
    final repository = await ref.read(productRepositoryProvider.future);
    await repository.clearSlot(slotId);
    ref.invalidate(placedProductsProvider);
  }
}

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

class VendingSessionState {
  const VendingSessionState({
    this.phase = VendingMachinePhase.ready,
    this.isCoinSettlementOpen = false,
    this.currentSlotInput = '',
    this.selectedSlotCode,
    this.selectedProduct,
    this.insertedAmountCents = 0,
    this.insertedCoins = const <int, int>{},
    this.outputProduct,
    this.outputChange = const <int, int>{},
    this.statusMessage = 'Bitte Produktposition eingeben.',
    this.coinInventory = defaultCoinInventory,
    this.coinSurplus = defaultCoinSurplus,
    this.coinEarnedSurplus = defaultCoinEarnedSurplus,
    this.coinOwnCoins = defaultCoinOwnCoins,
    this.coinTargetStock = defaultCoinTargetStock,
    this.coinDesignPaths = const <int, String?>{},
    this.changeDispenseCount = 20,
    this.dispenseContainerFillLevel = 1,
    this.dispenseHistory = const <DispenseRecord>[],
  });

  final VendingMachinePhase phase;
  final bool isCoinSettlementOpen;
  bool get hasPendingChange =>
      outputChange.values.any((quantity) => quantity > 0);
  bool get canUseSlotKeys =>
      phase == VendingMachinePhase.ready &&
      !isCoinSettlementOpen &&
      !hasPendingChange;
  bool get canClearSelection =>
      (phase == VendingMachinePhase.ready &&
          !isCoinSettlementOpen &&
          !hasPendingChange) ||
      phase == VendingMachinePhase.paymentInProgress;
  bool get canInsertCoins => phase == VendingMachinePhase.paymentInProgress;
  bool get canAcceptCustomerInput =>
      canUseSlotKeys || canInsertCoins || canClearSelection;
  final String currentSlotInput;
  final String? selectedSlotCode;
  final PlacedProduct? selectedProduct;
  final int insertedAmountCents;
  final Map<int, int> insertedCoins;
  final PlacedProduct? outputProduct;
  final Map<int, int> outputChange;
  final String statusMessage;
  final Map<int, int> coinInventory;
  final Map<int, int> coinSurplus;
  final Map<int, int> coinEarnedSurplus;
  final Map<int, int> coinOwnCoins;
  final Map<int, int> coinTargetStock;
  final Map<int, String?> coinDesignPaths;
  final int changeDispenseCount;
  final int dispenseContainerFillLevel;
  final List<DispenseRecord> dispenseHistory;

  int get totalCoinInventory =>
      coinInventory.values.fold<int>(0, (sum, count) => sum + count);

  int get totalCoinSurplus =>
      coinSurplus.values.fold<int>(0, (sum, count) => sum + count);

  int coinHarvestableQuantity(int denominationCents) {
    final inventory = coinInventory[denominationCents] ?? 0;
    final target = coinTargetStock[denominationCents] ?? 0;
    final physicalSurplus = coinSurplus[denominationCents] ?? 0;
    final cassetteExcess = inventory - target;

    return physicalSurplus + (cassetteExcess > 0 ? cassetteExcess : 0);
  }

  int get totalCoinHarvestable => coinDenominationsCents.fold<int>(
    0,
    (sum, denomination) => sum + coinHarvestableQuantity(denomination),
  );

  int get totalHarvestableValueCents => coinDenominationsCents.fold<int>(
    0,
    (sum, denomination) =>
        sum + denomination * coinHarvestableQuantity(denomination),
  );

  int get totalCoinEarnedSurplus =>
      coinEarnedSurplus.values.fold<int>(0, (sum, count) => sum + count);

  int get totalEarnedSurplusValueCents => coinEarnedSurplus.entries.fold<int>(
    0,
    (sum, entry) => sum + entry.key * entry.value,
  );

  int get totalCoinOwnCoins =>
      coinOwnCoins.values.fold<int>(0, (sum, count) => sum + count);

  int get totalOwnCoinValueCents => coinOwnCoins.entries.fold<int>(
    0,
    (sum, entry) => sum + entry.key * entry.value,
  );

  int get totalSurplusValueCents => coinSurplus.entries.fold<int>(
    0,
    (sum, entry) => sum + entry.key * entry.value,
  );

  int get totalCassetteValueCents => coinInventory.entries.fold<int>(
    0,
    (sum, entry) => sum + entry.key * entry.value,
  );

  int get totalMachineValueCents =>
      totalCassetteValueCents + totalSurplusValueCents;

  int coinRowTotalCents(int denominationCents) {
    final ist = coinInventory[denominationCents] ?? 0;
    final surplus = coinSurplus[denominationCents] ?? 0;
    return denominationCents * (ist + surplus);
  }

  String? get outputProductName => outputProduct?.name;

  int get missingAmountCents {
    final product = selectedProduct;

    if (product == null) {
      return 0;
    }

    final missing = product.priceCents - insertedAmountCents;
    return missing < 0 ? 0 : missing;
  }

  int? get expectedChangeCents {
    final product = selectedProduct;

    if (product == null) {
      return null;
    }

    final change = insertedAmountCents - product.priceCents;
    return change > 0 ? change : 0;
  }

  VendingSessionState copyWith({
    VendingMachinePhase? phase,
    bool? isCoinSettlementOpen,
    String? currentSlotInput,
    String? selectedSlotCode,
    bool clearSelectedSlotCode = false,
    PlacedProduct? selectedProduct,
    bool clearSelectedProduct = false,
    int? insertedAmountCents,
    Map<int, int>? insertedCoins,
    PlacedProduct? outputProduct,
    bool clearOutputProduct = false,
    Map<int, int>? outputChange,
    String? statusMessage,
    Map<int, int>? coinInventory,
    Map<int, int>? coinSurplus,
    Map<int, int>? coinEarnedSurplus,
    Map<int, int>? coinOwnCoins,
    Map<int, int>? coinTargetStock,
    Map<int, String?>? coinDesignPaths,
    int? changeDispenseCount,
    int? dispenseContainerFillLevel,
    List<DispenseRecord>? dispenseHistory,
  }) {
    return VendingSessionState(
      phase: phase ?? this.phase,
      isCoinSettlementOpen: isCoinSettlementOpen ?? this.isCoinSettlementOpen,
      currentSlotInput: currentSlotInput ?? this.currentSlotInput,
      selectedSlotCode: clearSelectedSlotCode
          ? null
          : selectedSlotCode ?? this.selectedSlotCode,
      selectedProduct: clearSelectedProduct
          ? null
          : selectedProduct ?? this.selectedProduct,
      insertedAmountCents: insertedAmountCents ?? this.insertedAmountCents,
      insertedCoins: insertedCoins ?? this.insertedCoins,
      outputProduct: clearOutputProduct
          ? null
          : outputProduct ?? this.outputProduct,
      outputChange: outputChange ?? this.outputChange,
      statusMessage: statusMessage ?? this.statusMessage,
      coinInventory: coinInventory ?? this.coinInventory,
      coinSurplus: coinSurplus ?? this.coinSurplus,
      coinEarnedSurplus: coinEarnedSurplus ?? this.coinEarnedSurplus,
      coinOwnCoins: coinOwnCoins ?? this.coinOwnCoins,
      coinTargetStock: coinTargetStock ?? this.coinTargetStock,
      coinDesignPaths: coinDesignPaths ?? this.coinDesignPaths,
      changeDispenseCount: changeDispenseCount ?? this.changeDispenseCount,
      dispenseContainerFillLevel:
          dispenseContainerFillLevel ?? this.dispenseContainerFillLevel,
      dispenseHistory: dispenseHistory ?? this.dispenseHistory,
    );
  }
}

class DispenseRecord {
  const DispenseRecord({
    required this.productName,
    required this.slotCode,
    required this.timestamp,
  });

  final String productName;
  final String slotCode;
  final DateTime timestamp;
}

class VendingSessionNotifier extends Notifier<VendingSessionState> {
  Timer? _slotInputTimer;
  Timer? _coinPersistTimer;
  var _coinStateLoaded = false;
  Timer? _customerFlowTimer;
  bool _autoPurchaseInProgress = false;

  /// Wahlweise: der 3D-Startbildschirm setzt das für die Fall-Animation vor Bestand −1.
  /// Signatur: `(slotCode, visibleStockBeforeDecrement) → Future`
  Future<void> Function(String slotCode, int visibleStock)? dispenseAnimationHandler;

  @override
  VendingSessionState build() {
    ref.onDispose(() {
      _slotInputTimer?.cancel();
      _coinPersistTimer?.cancel();
      _customerFlowTimer?.cancel();
    });

    Future.microtask(_loadPersistedCoinState);

    return const VendingSessionState();
  }

  Future<void> _loadPersistedCoinState() async {
    if (_coinStateLoaded) {
      return;
    }

    try {
      final db = await ref.read(databaseProvider.future);
      final snapshot = await CoinRepository(db).loadSnapshot();
      _coinStateLoaded = true;

      state = state.copyWith(
        coinInventory: snapshot.inventory,
        coinSurplus: snapshot.surplus,
        coinEarnedSurplus: snapshot.earnedSurplus,
        coinOwnCoins: snapshot.ownCoins,
        coinTargetStock: snapshot.targetStock,
        coinDesignPaths: snapshot.designPaths,
        changeDispenseCount: snapshot.changeDispenseCount,
        dispenseContainerFillLevel: snapshot.dispenseContainerFillLevel,
      );
    } catch (error) {
      debugPrint('VendingSession: Münzdaten laden fehlgeschlagen: $error');
    }
  }

  void _scheduleCoinPersist() {
    _coinPersistTimer?.cancel();
    _coinPersistTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final db = await ref.read(databaseProvider.future);
        await CoinRepository(db).saveSnapshot(
          CoinSnapshot(
            inventory: state.coinInventory,
            surplus: state.coinSurplus,
            earnedSurplus: state.coinEarnedSurplus,
            ownCoins: state.coinOwnCoins,
            targetStock: state.coinTargetStock,
            designPaths: state.coinDesignPaths,
            changeDispenseCount: state.changeDispenseCount,
            dispenseContainerFillLevel: state.dispenseContainerFillLevel,
          ),
        );
      } catch (error) {
        debugPrint(
          'VendingSession: Münzdaten speichern fehlgeschlagen: $error',
        );
      }
    });
  }

  void pressSlotKey(String key) {
    if (!state.canUseSlotKeys) {
      return;
    }

    final normalizedKey = key.toUpperCase();

    if (_isRowKey(normalizedKey)) {
      _setSlotInput(normalizedKey);
      return;
    }

    if (_isDigitKey(normalizedKey)) {
      final currentInput = state.currentSlotInput;

      if (currentInput.isEmpty || !_isRowKey(currentInput[0])) {
        state = state.copyWith(statusMessage: 'Bitte zuerst A bis F eingeben.');
        return;
      }

      if (currentInput.length >= 3) {
        state = state.copyWith(
          statusMessage: 'Slot-Code darf maximal 3 Zeichen haben.',
        );
        return;
      }

      final nextInput = '$currentInput$normalizedKey';
      final parsed = SlotCode.tryParse(nextInput);
      if (parsed != null &&
          !isValidUserSlotSelection(
            rowLabel: parsed.rowLabel,
            columnNumber: parsed.columnNumber,
          )) {
        _rejectSlotSelection(
          message: 'Ungültiger Slot — neues Produkt wählen.',
        );
        return;
      }

      _setSlotInput(nextInput);
      return;
    }

    state = state.copyWith(statusMessage: 'Ungültige Taste.');
  }

  void clearSlotInput() {
    if (!state.canClearSelection) {
      return;
    }

    _slotInputTimer?.cancel();

    final refundedCoins = Map<int, int>.from(state.insertedCoins)
      ..removeWhere((denomination, quantity) => quantity <= 0);
    final hasRefund = refundedCoins.isNotEmpty;

    state = state.copyWith(
      phase: VendingMachinePhase.ready,
      currentSlotInput: '',
      clearSelectedSlotCode: true,
      clearSelectedProduct: true,
      insertedAmountCents: 0,
      insertedCoins: const <int, int>{},
      clearOutputProduct: true,
      outputChange: hasRefund ? refundedCoins : const <int, int>{},
      statusMessage: hasRefund
          ? 'Geld wird zurückgegeben.'
          : 'Bitte Produktposition eingeben.',
    );
  }

  void backspaceSlotInput() {
    if (!state.canUseSlotKeys) {
      return;
    }

    final input = state.currentSlotInput;

    if (input.isEmpty) {
      return;
    }

    final newInput = input.substring(0, input.length - 1);

    state = state.copyWith(
      currentSlotInput: newInput,
      clearSelectedSlotCode: true,
      clearSelectedProduct: true,
      statusMessage: newInput.isEmpty
          ? 'Bitte Produktposition eingeben.'
          : 'Eingabe: $newInput',
    );

    _slotInputTimer?.cancel();

    if (newInput.isNotEmpty) {
      _restartSlotInputTimer();
    }
  }

  void processSlotInputAfterDelay() {
    if (!state.canUseSlotKeys) {
      return;
    }

    final slotCode = state.currentSlotInput.toUpperCase();

    if (slotCode.isEmpty) {
      state = state.copyWith(statusMessage: 'Bitte Produktposition eingeben.');
      return;
    }

    // Noch unvollständig (nur Buchstabe) → zurück zur Auswahl.
    if (slotCode.length < 2) {
      _rejectSlotSelection(
        message: 'Eingabe unvollständig — neues Produkt wählen.',
      );
      return;
    }

    selectProductBySlot(slotCode);
  }

  void selectProductBySlot(String slotCode) {
    unawaited(_selectProductBySlotAsync(slotCode));
  }

  Future<void> _selectProductBySlotAsync(String slotCode) async {
    if (!state.canUseSlotKeys) {
      return;
    }

    final parsedSlot = SlotCode.tryParse(slotCode);

    if (parsedSlot == null) {
      _rejectSlotSelection(
        message: 'Ungültiger Slot — neues Produkt wählen.',
      );
      return;
    }

    if (!isValidUserSlotSelection(
      rowLabel: parsedSlot.rowLabel,
      columnNumber: parsedSlot.columnNumber,
    )) {
      _rejectSlotSelection(
        message: 'Ungültiger Slot — neues Produkt wählen.',
      );
      return;
    }

    List<PlacedProduct> placed;
    final asyncPlaced = ref.read(placedProductsProvider);
    if (!asyncPlaced.hasValue) {
      state = state.copyWith(
        statusMessage: 'Bestand wird geladen…',
      );
      try {
        placed = await ref.read(placedProductsProvider.future);
      } catch (error) {
        debugPrint('Slot-Auswahl: Bestand laden fehlgeschlagen: $error');
        _rejectSlotSelection(
          message: 'Bestand nicht verfügbar — bitte erneut versuchen.',
        );
        return;
      }
      if (!state.canUseSlotKeys) return;
    } else {
      placed = asyncPlaced.requireValue;
    }

    debugPrint(
      'Slot-Auswahl ${parsedSlot.code}: ${placed.length} belegte Slots '
      '(${placed.map((p) => '${p.slotCode}:${p.stockQuantity}').take(8).join(', ')}…)',
    );

    final lookupCol = isDoubleSlotRow(parsedSlot.rowLabel)
        ? mapDoubleSlotInputToPhysicalStart(parsedSlot.columnNumber)
        : parsedSlot.columnNumber;

    final match = _findPlacedAtSlot(
      placed: placed,
      rowLabel: parsedSlot.rowLabel,
      columnNumber: lookupCol,
    );

    final displayCode = isDoubleSlotRow(parsedSlot.rowLabel)
        ? '${parsedSlot.rowLabel}${physicalStartToDoubleSlotLabel(lookupCol)}'
        : parsedSlot.code;

    if (match == null) {
      _rejectSlotSelection(
        message: '$displayCode ist leer — neues Produkt wählen.',
      );
      return;
    }

    if (match.isSoldOut) {
      _rejectSlotSelection(
        message: '$displayCode ist ausverkauft — neues Produkt wählen.',
      );
      return;
    }

    // E/F: Anzeige F1–F5 (Schild); Ausgabe nutzt physischen Start über Zuordnung.
    selectPlacedProduct(match, selectedSlotCode: displayCode);
  }

  void selectPlacedProduct(PlacedProduct placed, {String? selectedSlotCode}) {
    _beginPaymentSelection(
      placed,
      selectedSlotCode: selectedSlotCode ?? _displaySlotCode(placed),
    );
  }

  /// E/F: Schild-Code F1–F5; sonst physischer Slot-Code.
  String _displaySlotCode(PlacedProduct placed) {
    return displaySlotCode(
      rowLabel: placed.rowLabel,
      columnNumber: placed.columnNumber,
    );
  }

  /// Leerer / ungültiger / ausverkaufter Slot → Ruhezustand + Meldung.
  void _rejectSlotSelection({required String message}) {
    _slotInputTimer?.cancel();
    state = state.copyWith(
      phase: VendingMachinePhase.ready,
      currentSlotInput: '',
      clearSelectedSlotCode: true,
      clearSelectedProduct: true,
      clearOutputProduct: true,
      outputChange: const <int, int>{},
      statusMessage: message,
    );
  }

  void selectProduct(Product product, {String? selectedSlotCode}) {
    final placed =
        ref.read(placedProductsProvider).value ?? const <PlacedProduct>[];
    PlacedProduct? match;
    if (selectedSlotCode != null) {
      final parsed = SlotCode.tryParse(selectedSlotCode);
      if (parsed != null) {
        final lookupCol = isDoubleSlotRow(parsed.rowLabel)
            ? mapDoubleSlotInputToPhysicalStart(parsed.columnNumber)
            : parsed.columnNumber;
        match = _findPlacedAtSlot(
          placed: placed,
          rowLabel: parsed.rowLabel,
          columnNumber: lookupCol,
        );
      }
    }
    match ??= placed.where((p) => p.product.id == product.id).firstOrNull;
    if (match != null) {
      _beginPaymentSelection(match, selectedSlotCode: _displaySlotCode(match));
      return;
    }

    state = state.copyWith(
      clearSelectedProduct: true,
      selectedSlotCode: selectedSlotCode,
      statusMessage: 'Produkt hat keinen Slot.',
    );
  }

  void _beginPaymentSelection(
    PlacedProduct placed, {
    String? selectedSlotCode,
  }) {
    if (!state.canUseSlotKeys) {
      return;
    }

    final slotCode = selectedSlotCode ?? _displaySlotCode(placed);

    if (placed.isSoldOut) {
      _rejectSlotSelection(
        message: '$slotCode ist ausverkauft — neues Produkt wählen.',
      );
      return;
    }

    if (placed.priceCents <= 0) {
      _rejectSlotSelection(
        message:
            '$slotCode hat keinen Preis — bitte im Admin festlegen.',
      );
      return;
    }

    _slotInputTimer?.cancel();

    state = state.copyWith(
      phase: VendingMachinePhase.paymentInProgress,
      currentSlotInput: slotCode,
      selectedSlotCode: slotCode,
      selectedProduct: placed,
      clearOutputProduct: true,
      outputChange: const <int, int>{},
      statusMessage: 'Bitte bezahlen.',
    );
  }


  Future<void> insertCoin(int denominationCents) async {
    if (!state.canInsertCoins) {
      if (state.phase == VendingMachinePhase.ready &&
          state.selectedProduct == null) {
        state = state.copyWith(
          statusMessage: 'Bitte zuerst ein Produkt auswählen.',
        );
      }
      return;
    }

    if (_autoPurchaseInProgress) {
      return;
    }

    final product = state.selectedProduct;

    if (product == null) {
      state = state.copyWith(
        phase: VendingMachinePhase.ready,
        statusMessage: 'Bitte zuerst ein Produkt auswählen.',
      );
      return;
    }

    if (_isSelectedSoldOut()) {
      state = state.copyWith(
        statusMessage: 'Das ausgewählte Produkt ist ausverkauft.',
      );
      return;
    }

    if (!coinDenominationsCents.contains(denominationCents)) {
      state = state.copyWith(
        statusMessage: 'Diese Münze wird nicht akzeptiert.',
      );
      return;
    }

    final updatedInsertedCoins = Map<int, int>.from(state.insertedCoins);
    updatedInsertedCoins[denominationCents] =
        (updatedInsertedCoins[denominationCents] ?? 0) + 1;
    final updatedAmount = state.insertedAmountCents + denominationCents;

    state = state.copyWith(
      insertedAmountCents: updatedAmount,
      insertedCoins: updatedInsertedCoins,
      statusMessage: updatedAmount >= product.priceCents
          ? 'Zahlung vollständig. Kauf wird verarbeitet.'
          : 'Münze eingeworfen.',
    );

    await _tryAutoPurchase();
  }

  Future<void> _tryAutoPurchase() async {
    if (state.phase != VendingMachinePhase.paymentInProgress) {
      return;
    }

    final product = state.selectedProduct;

    if (product == null) {
      return;
    }

    if (_isSelectedSoldOut()) {
      return;
    }

    if (state.insertedAmountCents < product.priceCents) {
      return;
    }

    if (_autoPurchaseInProgress) {
      return;
    }

    _autoPurchaseInProgress = true;

    try {
      await buySelectedProduct();
    } finally {
      _autoPurchaseInProgress = false;
    }
  }

  void cancelPurchase() {
    _slotInputTimer?.cancel();

    if (state.insertedAmountCents == 0) {
      state = state.copyWith(
        currentSlotInput: '',
        clearSelectedSlotCode: true,
        clearSelectedProduct: true,
        statusMessage: 'Auswahl abgebrochen.',
      );
      return;
    }

    state = VendingSessionState(
      coinInventory: state.coinInventory,
      coinSurplus: state.coinSurplus,
      coinEarnedSurplus: state.coinEarnedSurplus,
      coinOwnCoins: state.coinOwnCoins,
      coinTargetStock: state.coinTargetStock,
      coinDesignPaths: state.coinDesignPaths,
      changeDispenseCount: state.changeDispenseCount,
      dispenseContainerFillLevel: state.dispenseContainerFillLevel,
      outputChange: state.insertedCoins,
      dispenseHistory: state.dispenseHistory,
      statusMessage: '${formatCents(state.insertedAmountCents)} zurückgegeben.',
    );
  }

  Future<void> buySelectedProduct() async {
    _slotInputTimer?.cancel();

    final selectedProduct = state.selectedProduct;

    if (selectedProduct == null) {
      state = state.copyWith(statusMessage: 'Kein Produkt ausgewählt.');
      return;
    }

    final placed = _findCurrentProduct(selectedProduct);

    if (placed.isSoldOut) {
      state = state.copyWith(statusMessage: 'Produkt ist ausverkauft.');
      return;
    }

    final currentProduct = placed;

    if (state.insertedAmountCents < currentProduct.priceCents) {
      state = state.copyWith(
        statusMessage:
            'Noch ${formatCents(state.missingAmountCents)} einwerfen.',
      );
      return;
    }

    final changeAmount = state.insertedAmountCents - currentProduct.priceCents;
    final availableCoins = _addCoinMaps(
      state.coinInventory,
      state.insertedCoins,
    );

    final changeCoins = ChangeCalculator.calculate(
      changeCents: changeAmount,
      inventory: availableCoins,
    );

    if (changeCoins == null) {
      state = state.copyWith(statusMessage: 'Wechselgeld nicht möglich.');
      return;
    }

    // E/F: Schild-Code F1–F5 an 3D (JS bildet auf physische Spiralen/Meshes ab).
    final slotCode = state.selectedSlotCode ?? _displaySlotCode(placed);
    final visibleStock = placed.stockQuantity;

    state = state.copyWith(
      phase: VendingMachinePhase.dispensing,
      selectedSlotCode: slotCode,
      statusMessage: 'Produkt wird ausgegeben...',
    );

    // Animation zuerst, danach Bestand −1 (Münzen schon geprüft).
    final handler = dispenseAnimationHandler;
    if (handler != null) {
      debugPrint('Dispense-Animation Slot $slotCode Stock=$visibleStock');
      await handler(slotCode, visibleStock);
    } else {
      debugPrint(
        'Dispense-Animation fehlt (kein 3D-Handler) — Fallback-Delay',
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (state.phase != VendingMachinePhase.dispensing) {
      return;
    }

    bool productWasUpdated;

    try {
      productWasUpdated = await ref
          .read(placedProductsProvider.notifier)
          .decreaseStockAfterPurchase(placed);
    } catch (_) {
      _customerFlowTimer?.cancel();

      state = state.copyWith(
        phase: VendingMachinePhase.outOfService,
        statusMessage: 'Technischer Fehler. Automat außer Betrieb.',
      );
      return;
    }

    if (!productWasUpdated) {
      state = state.copyWith(
        phase: VendingMachinePhase.ready,
        statusMessage: 'Produkt ist nicht mehr verfügbar.',
      );
      return;
    }

    final inventoryAfterChange = _subtractCoinMap(availableCoins, changeCoins);
    final newCoinInventory = <int, int>{};
    final newCoinSurplus = Map<int, int>.from(state.coinSurplus);

    for (final denomination in coinDenominationsCents) {
      final quantity = inventoryAfterChange[denomination] ?? 0;

      if (quantity > coinCassetteCapacity) {
        final overflow = quantity - coinCassetteCapacity;
        newCoinInventory[denomination] = coinCassetteCapacity;
        newCoinSurplus[denomination] =
            (newCoinSurplus[denomination] ?? 0) + overflow;
      } else {
        newCoinInventory[denomination] = quantity;
      }
    }

    final newEarnedSurplus = <int, int>{};
    final newOwnCoins = <int, int>{};

    for (final denomination in coinDenominationsCents) {
      final inventoryBefore = state.coinInventory[denomination] ?? 0;
      final ownBefore = state.coinOwnCoins[denomination] ?? 0;
      final earnedBefore = state.coinEarnedSurplus[denomination] ?? 0;
      final inserted = state.insertedCoins[denomination] ?? 0;
      final dispensed = changeCoins[denomination] ?? 0;
      final ownInCassette = ownBefore < inventoryBefore
          ? ownBefore
          : inventoryBefore;
      final dispensedOwn = dispensed < ownInCassette
          ? dispensed
          : ownInCassette;
      final dispensedEarned = dispensed - dispensedOwn;

      newOwnCoins[denomination] = ownBefore - dispensedOwn;
      newEarnedSurplus[denomination] =
          earnedBefore + inserted - dispensedEarned;
    }
    final dispenseRecord = DispenseRecord(
      productName: currentProduct.name,
      slotCode: slotCode,
      timestamp: DateTime.now(),
    );

    final changeCoinCount = changeCoins.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    final paidAmountCents = state.insertedAmountCents;

    state = state.copyWith(
      phase: VendingMachinePhase.dispensing,
      coinInventory: newCoinInventory,
      coinSurplus: newCoinSurplus,
      coinEarnedSurplus: newEarnedSurplus,
      coinOwnCoins: newOwnCoins,
      coinTargetStock: state.coinTargetStock,
      coinDesignPaths: state.coinDesignPaths,
      changeDispenseCount: state.changeDispenseCount + changeCoinCount,
      dispenseContainerFillLevel: state.dispenseContainerFillLevel,
      outputProduct: currentProduct,
      outputChange: changeCoins,
      dispenseHistory: [
        dispenseRecord,
        ...state.dispenseHistory,
      ].take(20).toList(),
      statusMessage: 'Produkt wird ausgegeben.',
    );

    _scheduleCoinPersist();
    _startPostPurchaseFlow();

    final productId = currentProduct.id;
    if (productId != null) {
      try {
        final db = await ref.read(databaseProvider.future);
        await TransactionRepository(db).recordSale(
          productId: productId,
          amountPaidCents: paidAmountCents,
          changeGivenCents: changeAmount,
        );
      } catch (error) {
        debugPrint(
          'VendingSession: Transaktion speichern fehlgeschlagen: $error',
        );
      }
    }
  }

  void _startPostPurchaseFlow() {
    _customerFlowTimer?.cancel();

    _customerFlowTimer = Timer(purchaseResultDisplayDuration, () {
      if (state.phase != VendingMachinePhase.dispensing) {
        return;
      }

      state = state.copyWith(
        phase: VendingMachinePhase.thankYou,
        statusMessage: 'Vielen Dank für Ihren Einkauf.',
      );

      _customerFlowTimer = Timer(
        thankYouSequenceDuration,
        _resetForNextCustomer,
      );
    });
  }

  void _resetForNextCustomer() {
    _customerFlowTimer?.cancel();
    _slotInputTimer?.cancel();

    if (state.phase != VendingMachinePhase.thankYou) {
      return;
    }

    state = VendingSessionState(
      coinInventory: state.coinInventory,
      coinSurplus: state.coinSurplus,
      coinEarnedSurplus: state.coinEarnedSurplus,
      coinOwnCoins: state.coinOwnCoins,
      coinTargetStock: state.coinTargetStock,
      coinDesignPaths: state.coinDesignPaths,
      changeDispenseCount: state.changeDispenseCount,
      dispenseContainerFillLevel: state.dispenseContainerFillLevel,
      dispenseHistory: state.dispenseHistory,
    );
  }

  /// Entnimmt Münzen aus der Wechselgeldausgabe und schaltet die Bedienung frei.
  void collectOutputChange() {
    if (!state.hasPendingChange) {
      return;
    }

    _customerFlowTimer?.cancel();
    _slotInputTimer?.cancel();

    final unlockAfterPurchase =
        state.phase == VendingMachinePhase.dispensing ||
        state.phase == VendingMachinePhase.thankYou;

    if (unlockAfterPurchase) {
      state = VendingSessionState(
        coinInventory: state.coinInventory,
        coinSurplus: state.coinSurplus,
        coinEarnedSurplus: state.coinEarnedSurplus,
        coinOwnCoins: state.coinOwnCoins,
        coinTargetStock: state.coinTargetStock,
        coinDesignPaths: state.coinDesignPaths,
        changeDispenseCount: state.changeDispenseCount,
        dispenseContainerFillLevel: state.dispenseContainerFillLevel,
        dispenseHistory: state.dispenseHistory,
        statusMessage: 'Wechselgeld entnommen. Bitte Produktposition eingeben.',
      );
      return;
    }

    state = state.copyWith(
      outputChange: const <int, int>{},
      statusMessage: 'Wechselgeld entnommen. Bitte Produktposition eingeben.',
    );
  }

  void markOutOfService(String message) {
    _customerFlowTimer?.cancel();
    _slotInputTimer?.cancel();

    state = state.copyWith(
      phase: VendingMachinePhase.outOfService,
      statusMessage: message,
    );
  }

  void startCoinSettlement() {
    if (state.phase != VendingMachinePhase.ready ||
        state.isCoinSettlementOpen) {
      return;
    }

    state = state.copyWith(
      isCoinSettlementOpen: true,
      statusMessage: 'Kassette für die Abrechnung geöffnet.',
    );
  }

  void finishCoinSettlement() {
    if (state.phase != VendingMachinePhase.ready ||
        !state.isCoinSettlementOpen) {
      return;
    }

    state = state.copyWith(
      isCoinSettlementOpen: false,
      statusMessage: 'Kassenabrechnung beendet.',
    );
  }

  void addCoinsToInventory(int denominationCents, int quantity) {
    if (quantity <= 0) {
      return;
    }

    final coinInventory = Map<int, int>.from(state.coinInventory);
    final coinSurplus = Map<int, int>.from(state.coinSurplus);
    final coinOwnCoins = Map<int, int>.from(state.coinOwnCoins);
    final current = coinInventory[denominationCents] ?? 0;
    final next = current + quantity;

    if (next > coinCassetteCapacity) {
      final overflow = next - coinCassetteCapacity;
      coinInventory[denominationCents] = coinCassetteCapacity;
      coinSurplus[denominationCents] =
          (coinSurplus[denominationCents] ?? 0) + overflow;
    } else {
      coinInventory[denominationCents] = next;
    }
    coinOwnCoins[denominationCents] =
        (coinOwnCoins[denominationCents] ?? 0) + quantity;

    state = state.copyWith(
      coinInventory: coinInventory,
      coinSurplus: coinSurplus,
      coinOwnCoins: coinOwnCoins,
      statusMessage:
          '$quantity x ${formatCents(denominationCents)} aufgefüllt.',
    );
    _scheduleCoinPersist();
  }

  void fillCoinToTarget(int denominationCents) {
    if (state.phase != VendingMachinePhase.ready) {
      return;
    }

    final current = state.coinInventory[denominationCents] ?? 0;
    final target = state.coinTargetStock[denominationCents] ?? 0;
    final missing = target > current ? target - current : 0;

    if (missing == 0) {
      return;
    }

    addCoinsToInventory(denominationCents, missing);
  }

  void removeCoinsFromInventory(int denominationCents, int quantity) {
    if (quantity <= 0) {
      return;
    }

    final coinInventory = Map<int, int>.from(state.coinInventory);
    final coinOwnCoins = Map<int, int>.from(state.coinOwnCoins);
    final coinEarnedSurplus = Map<int, int>.from(state.coinEarnedSurplus);
    final current = coinInventory[denominationCents] ?? 0;
    final next = current - quantity;

    if (next < 0) {
      return;
    }

    coinInventory[denominationCents] = next;
    final own = coinOwnCoins[denominationCents] ?? 0;
    final ownInCassette = own < current ? own : current;
    final removedOwn = quantity < ownInCassette ? quantity : ownInCassette;
    final removedEarned = quantity - removedOwn;
    coinOwnCoins[denominationCents] = own - removedOwn;
    coinEarnedSurplus[denominationCents] =
        (coinEarnedSurplus[denominationCents] ?? 0) - removedEarned;

    state = state.copyWith(
      coinInventory: coinInventory,
      coinEarnedSurplus: coinEarnedSurplus,
      coinOwnCoins: coinOwnCoins,
      statusMessage: '$quantity x ${formatCents(denominationCents)} entnommen.',
    );
    _scheduleCoinPersist();
  }

  void setCoinDesignPath(int denominationCents, String? path) {
    final coinDesignPaths = Map<int, String?>.from(state.coinDesignPaths);
    coinDesignPaths[denominationCents] = path;

    state = state.copyWith(
      coinDesignPaths: coinDesignPaths,
      statusMessage: path == null
          ? 'Münz-Design zurückgesetzt.'
          : 'Münz-Design für ${formatCents(denominationCents)} hochgeladen.',
    );
    _scheduleCoinPersist();
  }

  void setCoinTargetStock(int denominationCents, int target) {
    if (target < 0) {
      return;
    }

    final coinTargetStock = Map<int, int>.from(state.coinTargetStock);
    coinTargetStock[denominationCents] = target;

    state = state.copyWith(
      coinTargetStock: coinTargetStock,
      statusMessage:
          'Soll-Bestand ${formatCents(denominationCents)}: $target Stk.',
    );
    _scheduleCoinPersist();
  }

  void harvestEarnedSurplus(int denominationCents) {
    if (state.phase != VendingMachinePhase.ready ||
        !state.isCoinSettlementOpen) {
      return;
    }

    final earned = state.coinEarnedSurplus[denominationCents] ?? 0;
    if (earned == 0) {
      return;
    }

    final coinInventory = Map<int, int>.from(state.coinInventory);
    final coinSurplus = Map<int, int>.from(state.coinSurplus);
    final coinEarnedSurplus = Map<int, int>.from(state.coinEarnedSurplus);
    final inventory = coinInventory[denominationCents] ?? 0;
    final surplus = coinSurplus[denominationCents] ?? 0;
    final own = state.coinOwnCoins[denominationCents] ?? 0;
    final ownInCassette = own < inventory ? own : inventory;
    final earnedInCassette = inventory - ownInCassette;
    final earnedInSurplus = earned - earnedInCassette;

    coinInventory[denominationCents] = inventory - earnedInCassette;
    coinSurplus[denominationCents] = surplus - earnedInSurplus;
    coinEarnedSurplus[denominationCents] = 0;

    state = state.copyWith(
      coinInventory: coinInventory,
      coinSurplus: coinSurplus,
      coinEarnedSurplus: coinEarnedSurplus,
      statusMessage:
          'Einnahmen: $earned x ${formatCents(denominationCents)} abgeschöpft.',
    );
    _scheduleCoinPersist();
  }

  void emptyCoinDenomination(int denominationCents) {
    if (state.phase != VendingMachinePhase.ready) {
      return;
    }

    final inventory = state.coinInventory[denominationCents] ?? 0;
    final surplus = state.coinSurplus[denominationCents] ?? 0;
    final removedQuantity = inventory + surplus;

    if (removedQuantity == 0) {
      return;
    }

    final coinInventory = Map<int, int>.from(state.coinInventory);
    final coinSurplus = Map<int, int>.from(state.coinSurplus);
    final coinOwnCoins = Map<int, int>.from(state.coinOwnCoins);
    final coinEarnedSurplus = Map<int, int>.from(state.coinEarnedSurplus);

    coinInventory[denominationCents] = 0;
    coinSurplus[denominationCents] = 0;
    coinOwnCoins[denominationCents] = 0;
    coinEarnedSurplus[denominationCents] = 0;

    final hasRemainingSurplus = coinSurplus.values.any(
      (quantity) => quantity > 0,
    );

    state = state.copyWith(
      coinInventory: coinInventory,
      coinSurplus: coinSurplus,
      coinOwnCoins: coinOwnCoins,
      coinEarnedSurplus: coinEarnedSurplus,
      dispenseContainerFillLevel: hasRemainingSurplus
          ? state.dispenseContainerFillLevel
          : 0,
      statusMessage:
          '$removedQuantity x ${formatCents(denominationCents)} vollständig entnommen.',
    );
    _scheduleCoinPersist();
  }

  void harvestAllEarnedSurplus() {
    if (state.phase != VendingMachinePhase.ready ||
        !state.isCoinSettlementOpen) {
      return;
    }

    final hadEarnedSurplus = state.totalCoinEarnedSurplus > 0;
    final coinInventory = Map<int, int>.from(state.coinInventory);
    final coinSurplus = Map<int, int>.from(state.coinSurplus);

    for (final denomination in coinDenominationsCents) {
      final inventory = coinInventory[denomination] ?? 0;
      final surplus = coinSurplus[denomination] ?? 0;
      final own = state.coinOwnCoins[denomination] ?? 0;
      final earned = state.coinEarnedSurplus[denomination] ?? 0;
      final ownInCassette = own < inventory ? own : inventory;
      final earnedInCassette = inventory - ownInCassette;
      final earnedInSurplus = earned - earnedInCassette;

      coinInventory[denomination] = inventory - earnedInCassette;
      coinSurplus[denomination] = surplus - earnedInSurplus;
    }

    state = state.copyWith(
      coinInventory: coinInventory,
      coinSurplus: coinSurplus,
      coinEarnedSurplus: {
        for (final denomination in coinDenominationsCents) denomination: 0,
      },
      statusMessage: hadEarnedSurplus
          ? 'Alle erwirtschafteten Einnahmen abgeschöpft.'
          : 'Keine erwirtschafteten Einnahmen vorhanden.',
    );
    _scheduleCoinPersist();
  }

  void returnAllOwnChangeCoins() {
    if (state.phase != VendingMachinePhase.ready ||
        !state.isCoinSettlementOpen) {
      return;
    }

    final hadOwnCoins = state.totalCoinOwnCoins > 0;
    final coinInventory = Map<int, int>.from(state.coinInventory);
    final coinSurplus = Map<int, int>.from(state.coinSurplus);

    for (final denomination in coinDenominationsCents) {
      final inventory = coinInventory[denomination] ?? 0;
      final surplus = coinSurplus[denomination] ?? 0;
      final own = state.coinOwnCoins[denomination] ?? 0;
      final ownInCassette = own < inventory ? own : inventory;
      final ownInSurplus = own - ownInCassette;

      coinInventory[denomination] = inventory - ownInCassette;
      coinSurplus[denomination] = surplus - ownInSurplus;
    }

    state = state.copyWith(
      coinInventory: coinInventory,
      coinSurplus: coinSurplus,
      coinOwnCoins: {
        for (final denomination in coinDenominationsCents) denomination: 0,
      },
      statusMessage: hadOwnCoins
          ? 'Eigene Wechselgeldmünzen zurückgeführt.'
          : 'Keine eigenen Wechselgeldmünzen vorhanden.',
    );
    _scheduleCoinPersist();
  }

  void clearCoinSurplus() {
    final coinSurplus = {
      for (final denomination in coinDenominationsCents) denomination: 0,
    };
    final coinOwnCoins = <int, int>{};
    final coinEarnedSurplus = <int, int>{};

    for (final denomination in coinDenominationsCents) {
      final inventory = state.coinInventory[denomination] ?? 0;
      final own = state.coinOwnCoins[denomination] ?? 0;
      final earned = state.coinEarnedSurplus[denomination] ?? 0;
      coinOwnCoins[denomination] = own < inventory ? own : inventory;
      coinEarnedSurplus[denomination] =
          earned < inventory - coinOwnCoins[denomination]!
          ? earned
          : inventory - coinOwnCoins[denomination]!;
    }

    state = state.copyWith(
      coinSurplus: coinSurplus,
      coinEarnedSurplus: coinEarnedSurplus,
      coinOwnCoins: coinOwnCoins,
      dispenseContainerFillLevel: 0,
      statusMessage: 'Überschuss und Abwurfbehälter geleert.',
    );
    _scheduleCoinPersist();
  }

  void _setSlotInput(String input) {
    state = state.copyWith(
      currentSlotInput: input,
      clearSelectedSlotCode: true,
      clearSelectedProduct: true,
      clearOutputProduct: true,
      outputChange: const <int, int>{},
      statusMessage: 'Eingabe: $input',
    );

    _restartSlotInputTimer();
  }

  void _restartSlotInputTimer() {
    _slotInputTimer?.cancel();
    _slotInputTimer = Timer(
      slotInputCommitDelay,
      processSlotInputAfterDelay,
    );
  }

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

final _demoPlacedProducts = <PlacedProduct>[
  PlacedProduct(
    product: const Product(
      id: 1,
      name: 'Wasser',
      priceCents: 120,
      maxCapacity: 10,
      category: ProductCategory.drinks,
      slotWidth: 1,
      iconKey: 'water_drop',
    ),
    slot: const ProductSlot(
      productId: 1,
      rowLabel: 'A',
      columnNumber: 1,
      stockQuantity: 8,
      maxCapacity: 10,
    ),
  ),
  PlacedProduct(
    product: const Product(
      id: 2,
      name: 'Cola',
      priceCents: 180,
      maxCapacity: 8,
      category: ProductCategory.drinks,
      slotWidth: 1,
      iconKey: 'local_drink',
    ),
    slot: const ProductSlot(
      productId: 2,
      rowLabel: 'A',
      columnNumber: 2,
      stockQuantity: 5,
      maxCapacity: 8,
    ),
  ),
  PlacedProduct(
    product: const Product(
      id: 3,
      name: 'Schokoriegel',
      priceCents: 110,
      maxCapacity: 12,
      category: ProductCategory.snacksBars,
      slotWidth: 1,
      iconKey: 'fastfood',
    ),
    slot: const ProductSlot(
      productId: 3,
      rowLabel: 'C',
      columnNumber: 1,
      stockQuantity: 9,
      maxCapacity: 12,
    ),
  ),
  PlacedProduct(
    product: const Product(
      id: 4,
      name: 'Chips',
      priceCents: 220,
      maxCapacity: 6,
      category: ProductCategory.chips,
      slotWidth: 1,
      iconKey: 'lunch_dining',
    ),
    slot: const ProductSlot(
      productId: 4,
      rowLabel: 'C',
      columnNumber: 4,
      stockQuantity: 3,
      maxCapacity: 6,
    ),
  ),
];

final _demoProducts =
    _demoPlacedProducts.map((placed) => placed.product).toList();
