import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/constants/vending_coin_config.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/coin_repository.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/db_creater.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/product_repository.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/transaction_repository.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/change_calculator.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/local_file_cache.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/product_asset_storage.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/slot_code_parser.dart';
import 'package:sqflite/sqflite.dart';

export 'package:snackautomat_yakup_leandro/features_snack/constants/vending_coin_config.dart'
    show coinCassetteCapacity, coinDenominationsCents, formatCents;

enum VendingMachinePhase { ready, dispensing, thankYou, outOfService }

const purchaseResultDisplayDuration = Duration(seconds: 2);
const thankYouCharacterDuration = Duration(milliseconds: 45);
const thankYouHoldDuration = Duration(seconds: 2);
const changeDropDuration = Duration(milliseconds: 750);

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
        await _seedDemoProducts(repository);
        products = await repository.getProducts();
      }

      if (products.isNotEmpty) {
        return products;
      }
    } catch (error) {
      debugPrint('ProductController: Laden fehlgeschlagen: $error');
    }

    return _demoProducts;
  }

  Future<void> _seedDemoProducts(ProductRepository repository) async {
    for (final demo in _demoProducts) {
      try {
        await repository.saveProductAtSlot(
          demo.copyWith(
            id: null,
            imagePath: null,
            modelPath: null,
            modelPart: null,
          ),
        );
      } catch (error) {
        debugPrint(
          'ProductController: Demo-Produkt seed fehlgeschlagen: $error',
        );
      }
    }
  }

  Future<void> increaseStock(Product product) async {
    final products = state.value ?? const <Product>[];
    final index = _findProductIndex(products, product);

    if (index == -1) {
      return;
    }

    final current = products[index];

    if (current.stockQuantity >= current.maxCapacity) {
      return;
    }

    await _changeStock(product, 1);
  }

  Future<void> increaseStockBy(Product product, int amount) async {
    if (amount <= 0) {
      return;
    }

    final products = state.value ?? const <Product>[];
    final index = _findProductIndex(products, product);

    if (index == -1) {
      return;
    }

    final current = products[index];
    final targetStock = (current.stockQuantity + amount).clamp(
      0,
      current.maxCapacity,
    );
    final difference = targetStock - current.stockQuantity;

    if (difference <= 0) {
      return;
    }

    await _changeStock(product, difference);
  }

  Future<void> refillToMax(Product product) async {
    final products = state.value ?? const <Product>[];
    final index = _findProductIndex(products, product);

    if (index == -1) {
      return;
    }

    final current = products[index];

    if (current.stockQuantity >= current.maxCapacity) {
      return;
    }

    await _setStock(product, current.maxCapacity);
  }

  Future<void> setStockQuantity(Product product, int stockQuantity) async {
    final products = state.value ?? const <Product>[];
    final index = _findProductIndex(products, product);

    if (index == -1) {
      return;
    }

    final maxCapacity = products[index].maxCapacity;
    final clampedStock = stockQuantity.clamp(0, maxCapacity);

    await _setStock(product, clampedStock);
  }

  Future<void> decreaseStockForAdmin(Product product) async {
    await _changeStock(product, -1);
  }

  Future<void> saveProduct(Product product) async {
    try {
      final repository = await ref.read(productRepositoryProvider.future);
      await repository.saveProductAtSlot(product);
      LocalFileCache.invalidate(product.imagePath);
      LocalFileCache.invalidate(product.modelPath);
      await reloadProducts();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteProduct(Product product) async {
    final productId = product.id;

    if (productId == null) {
      final products = state.value ?? const <Product>[];
      state = AsyncData(
        products
            .where(
              (entry) =>
                  entry.rowLabel != product.rowLabel ||
                  entry.columnNumber != product.columnNumber,
            )
            .toList(),
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
      final products = state.value ?? const <Product>[];
      state = AsyncData(
        products.where((entry) => entry.id != productId).toList(),
      );
    }
  }

  Future<void> reloadProducts() async {
    try {
      final repository = await ref.read(productRepositoryProvider.future);
      var products = await repository.getProducts();

      if (products.isEmpty) {
        await _seedDemoProducts(repository);
        products = await repository.getProducts();
      }

      state = AsyncData(products.isEmpty ? _demoProducts : products);
    } catch (error) {
      debugPrint('ProductController: Reload fehlgeschlagen: $error');
      state = AsyncData(state.value ?? _demoProducts);
    }
  }

  Future<bool> decreaseStockAfterPurchase(Product product) async {
    final products = state.value ?? const <Product>[];
    final index = _findProductIndex(products, product);

    if (index == -1 || products[index].stockQuantity <= 0) {
      return false;
    }

    final updatedProduct = products[index].copyWith(
      stockQuantity: products[index].stockQuantity - 1,
    );

    final updatedProducts = [...products];
    updatedProducts[index] = updatedProduct;
    state = AsyncData(updatedProducts);

    await _persistStockIfPossible(updatedProduct);
    return true;
  }

  Future<void> _changeStock(Product product, int difference) async {
    final products = state.value ?? const <Product>[];
    final index = _findProductIndex(products, product);

    if (index == -1) {
      return;
    }

    final newStock = products[index].stockQuantity + difference;

    if (newStock < 0) {
      return;
    }

    final updatedProduct = products[index].copyWith(stockQuantity: newStock);

    final updatedProducts = [...products];
    updatedProducts[index] = updatedProduct;
    state = AsyncData(updatedProducts);

    await _persistStockIfPossible(updatedProduct);
  }

  Future<void> _setStock(Product product, int newStock) async {
    final products = state.value ?? const <Product>[];
    final index = _findProductIndex(products, product);

    if (index == -1) {
      return;
    }

    if (newStock < 0 || newStock > products[index].maxCapacity) {
      return;
    }

    final updatedProduct = products[index].copyWith(stockQuantity: newStock);

    final updatedProducts = [...products];
    updatedProducts[index] = updatedProduct;
    state = AsyncData(updatedProducts);

    await _persistStockIfPossible(updatedProduct);
  }

  Future<void> _persistStockIfPossible(Product product) async {
    final productId = product.id;

    if (productId == null) {
      return;
    }

    try {
      final repository = await ref.read(productRepositoryProvider.future);

      await repository.updateStockQuantity(
        productId: productId,
        stockQuantity: product.stockQuantity,
      );
    } catch (error) {
      debugPrint('ProductController: Bestand speichern fehlgeschlagen: $error');
    }
  }

  int _findProductIndex(List<Product> products, Product searchedProduct) {
    return products.indexWhere((product) {
      if (product.id != null && searchedProduct.id != null) {
        return product.id == searchedProduct.id;
      }

      return product.rowLabel == searchedProduct.rowLabel &&
          product.columnNumber == searchedProduct.columnNumber;
    });
  }
}

class VendingSessionState {
  const VendingSessionState({
    this.phase = VendingMachinePhase.ready,
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
    this.coinTargetStock = defaultCoinTargetStock,
    this.coinDesignPaths = const <int, String?>{},
    this.changeDispenseCount = 20,
    this.dispenseContainerFillLevel = 1,
    this.dispenseHistory = const <DispenseRecord>[],
  });

  final VendingMachinePhase phase;
  bool get canAcceptCustomerInput => phase == VendingMachinePhase.ready;
  final String currentSlotInput;
  final String? selectedSlotCode;
  final Product? selectedProduct;
  final int insertedAmountCents;
  final Map<int, int> insertedCoins;
  final Product? outputProduct;
  final Map<int, int> outputChange;
  final String statusMessage;
  final Map<int, int> coinInventory;
  final Map<int, int> coinSurplus;
  final Map<int, int> coinTargetStock;
  final Map<int, String?> coinDesignPaths;
  final int changeDispenseCount;
  final int dispenseContainerFillLevel;
  final List<DispenseRecord> dispenseHistory;

  int get totalCoinInventory =>
      coinInventory.values.fold<int>(0, (sum, count) => sum + count);

  int get totalCoinSurplus =>
      coinSurplus.values.fold<int>(0, (sum, count) => sum + count);

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
    String? currentSlotInput,
    String? selectedSlotCode,
    bool clearSelectedSlotCode = false,
    Product? selectedProduct,
    bool clearSelectedProduct = false,
    int? insertedAmountCents,
    Map<int, int>? insertedCoins,
    Product? outputProduct,
    bool clearOutputProduct = false,
    Map<int, int>? outputChange,
    String? statusMessage,
    Map<int, int>? coinInventory,
    Map<int, int>? coinSurplus,
    Map<int, int>? coinTargetStock,
    Map<int, String?>? coinDesignPaths,
    int? changeDispenseCount,
    int? dispenseContainerFillLevel,
    List<DispenseRecord>? dispenseHistory,
  }) {
    return VendingSessionState(
      phase: phase ?? this.phase,
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
    if (!_customerInputAllowed) {
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

      _setSlotInput('$currentInput$normalizedKey');
      return;
    }

    state = state.copyWith(statusMessage: 'Ungültige Taste.');
  }

  void clearSlotInput() {
    if (!_customerInputAllowed) {
      return;
    }

    _slotInputTimer?.cancel();

    final refundedCoins = Map<int, int>.from(state.insertedCoins)
      ..removeWhere((denomination, quantity) => quantity <= 0);
    final hasRefund = refundedCoins.isNotEmpty;

    state = state.copyWith(
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
    if (!_customerInputAllowed) {
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
    if (!_customerInputAllowed) {
      return;
    }

    final slotCode = state.currentSlotInput.toUpperCase();

    if (slotCode.isEmpty) {
      state = state.copyWith(statusMessage: 'Bitte Produktposition eingeben.');
      return;
    }

    selectProductBySlot(slotCode);
  }

  void selectProductBySlot(String slotCode) {
    if (!_customerInputAllowed) {
      return;
    }

    final parsedSlot = SlotCode.tryParse(slotCode);

    if (parsedSlot == null) {
      state = state.copyWith(
        currentSlotInput: '',
        clearSelectedSlotCode: true,
        statusMessage: 'Ungültiger Slot',
      );
      return;
    }

    final products =
        ref.read(productControllerProvider).value ?? const <Product>[];
    final product = _findProductAtSlot(
      products: products,
      rowLabel: parsedSlot.rowLabel,
      columnNumber: parsedSlot.columnNumber,
    );

    if (product == null) {
      state = state.copyWith(
        selectedSlotCode: parsedSlot.code,
        clearSelectedProduct: true,
        statusMessage: 'Kein Produkt auf ${parsedSlot.code}.',
      );
      return;
    }

    selectProduct(product, selectedSlotCode: parsedSlot.code);
  }

  void selectProduct(Product product, {String? selectedSlotCode}) {
    if (!_customerInputAllowed) {
      return;
    }

    if (product.isSoldOut) {
      state = state.copyWith(
        selectedSlotCode:
            selectedSlotCode ?? '${product.rowLabel}${product.columnNumber}',
        selectedProduct: product,
        statusMessage: 'Dieses Produkt ist ausverkauft.',
      );
      return;
    }

    final slotCode =
        selectedSlotCode ?? '${product.rowLabel}${product.columnNumber}';

    state = state.copyWith(
      currentSlotInput: slotCode,
      selectedSlotCode: slotCode,
      selectedProduct: product,
      clearOutputProduct: true,
      outputChange: const <int, int>{},
      statusMessage: '${product.name} ausgewählt.',
    );

    if (state.insertedAmountCents >= product.priceCents) {
      unawaited(_tryAutoPurchase());
    }
  }

  Future<void> insertCoin(int denominationCents) async {
    if (!_customerInputAllowed) {
      return;
    }

    if (_autoPurchaseInProgress) {
      return;
    }

    final product = state.selectedProduct;

    if (product == null) {
      state = state.copyWith(
        statusMessage: 'Bitte zuerst ein Produkt auswählen.',
      );
      return;
    }

    if (product.isSoldOut) {
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
    final product = state.selectedProduct;

    if (product == null) {
      return;
    }

    if (product.isSoldOut) {
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

    final currentProduct = _findCurrentProduct(selectedProduct);

    if (currentProduct.isSoldOut) {
      state = state.copyWith(statusMessage: 'Produkt ist ausverkauft.');
      return;
    }

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

    state = state.copyWith(
      phase: VendingMachinePhase.dispensing,
      statusMessage: 'Kauf wird verarbeitet.',
    );

    bool productWasUpdated;

    try {
      productWasUpdated = await ref
          .read(productControllerProvider.notifier)
          .decreaseStockAfterPurchase(currentProduct);
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

    final newCoinInventory = _subtractCoinMap(availableCoins, changeCoins);
    final slotCode =
        state.selectedSlotCode ??
        '${currentProduct.rowLabel}${currentProduct.columnNumber}';
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
      coinSurplus: state.coinSurplus,
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
      coinTargetStock: state.coinTargetStock,
      coinDesignPaths: state.coinDesignPaths,
      changeDispenseCount: state.changeDispenseCount,
      dispenseContainerFillLevel: state.dispenseContainerFillLevel,
      dispenseHistory: state.dispenseHistory,
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

  void addCoinsToInventory(int denominationCents, int quantity) {
    final coinInventory = Map<int, int>.from(state.coinInventory);
    final coinSurplus = Map<int, int>.from(state.coinSurplus);
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

    state = state.copyWith(
      coinInventory: coinInventory,
      coinSurplus: coinSurplus,
      statusMessage:
          '$quantity x ${formatCents(denominationCents)} aufgefüllt.',
    );
    _scheduleCoinPersist();
  }

  void removeCoinsFromInventory(int denominationCents, int quantity) {
    final coinInventory = Map<int, int>.from(state.coinInventory);
    final current = coinInventory[denominationCents] ?? 0;
    final next = current - quantity;

    if (next < 0) {
      return;
    }

    coinInventory[denominationCents] = next;

    state = state.copyWith(
      coinInventory: coinInventory,
      statusMessage: '$quantity x ${formatCents(denominationCents)} entnommen.',
    );
    _scheduleCoinPersist();
  }

  void emptyCoinCassette(int denominationCents) {
    final coinInventory = Map<int, int>.from(state.coinInventory);
    final coinSurplus = Map<int, int>.from(state.coinSurplus);
    final current = coinInventory[denominationCents] ?? 0;

    if (current == 0) {
      return;
    }

    coinSurplus[denominationCents] =
        (coinSurplus[denominationCents] ?? 0) + current;
    coinInventory[denominationCents] = 0;

    state = state.copyWith(
      coinInventory: coinInventory,
      coinSurplus: coinSurplus,
      dispenseContainerFillLevel: state.dispenseContainerFillLevel + 1,
      statusMessage: 'Kassette ${formatCents(denominationCents)} geleert.',
    );
    _scheduleCoinPersist();
  }

  void emptyAllCoinCassettes() {
    final coinInventory = <int, int>{};
    final coinSurplus = Map<int, int>.from(state.coinSurplus);

    for (final denomination in coinDenominationsCents) {
      final current = state.coinInventory[denomination] ?? 0;
      coinInventory[denomination] = 0;
      if (current > 0) {
        coinSurplus[denomination] = (coinSurplus[denomination] ?? 0) + current;
      }
    }

    state = state.copyWith(
      coinInventory: coinInventory,
      coinSurplus: coinSurplus,
      dispenseContainerFillLevel: state.dispenseContainerFillLevel + 1,
      statusMessage: 'Alle Geldkassetten geleert.',
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

  void skimCoinSurplus(int denominationCents) {
    final coinSurplus = Map<int, int>.from(state.coinSurplus);
    final skimmed = coinSurplus[denominationCents] ?? 0;

    if (skimmed == 0) {
      return;
    }

    coinSurplus[denominationCents] = 0;

    state = state.copyWith(
      coinSurplus: coinSurplus,
      statusMessage:
          'Abschöpfung: $skimmed x ${formatCents(denominationCents)} entnommen.',
    );
    _scheduleCoinPersist();
  }

  void skimAllCoinSurplus() {
    final hadSurplus = state.totalCoinSurplus > 0;

    state = state.copyWith(
      coinSurplus: {
        for (final denomination in coinDenominationsCents) denomination: 0,
      },
      dispenseContainerFillLevel: 0,
      statusMessage: hadSurplus
          ? 'Gesamter Überschuss abgeschöpft.'
          : 'Kein Überschuss vorhanden.',
    );
    _scheduleCoinPersist();
  }

  void clearCoinSurplus() {
    state = state.copyWith(
      coinSurplus: {
        for (final denomination in coinDenominationsCents) denomination: 0,
      },
      dispenseContainerFillLevel: 0,
      statusMessage: 'Überschuss und Abwurfbehälter geleert.',
    );
    _scheduleCoinPersist();
  }

  bool get _customerInputAllowed => state.phase == VendingMachinePhase.ready;

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
      const Duration(seconds: 2),
      processSlotInputAfterDelay,
    );
  }

  bool _isRowKey(String key) {
    return ['A', 'B', 'C', 'D', 'E', 'F'].contains(key);
  }

  bool _isDigitKey(String key) {
    return RegExp(r'^[0-9]$').hasMatch(key);
  }

  Product? _findProductAtSlot({
    required List<Product> products,
    required String rowLabel,
    required int columnNumber,
  }) {
    for (final product in products) {
      final productStart = product.columnNumber;
      final productEnd = product.columnNumber + product.slotWidth - 1;

      if (product.rowLabel.toUpperCase() == rowLabel &&
          columnNumber >= productStart &&
          columnNumber <= productEnd) {
        return product;
      }
    }

    return null;
  }

  Product _findCurrentProduct(Product selectedProduct) {
    final products = ref.read(productControllerProvider).value;

    if (products == null) {
      return selectedProduct;
    }

    for (final product in products) {
      if (product.id != null && selectedProduct.id != null) {
        if (product.id == selectedProduct.id) {
          return product;
        }
      } else if (product.rowLabel == selectedProduct.rowLabel &&
          product.columnNumber == selectedProduct.columnNumber) {
        return product;
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

final _demoProducts = <Product>[
  const Product(
    id: 1,
    name: 'Wasser',
    priceCents: 120,
    stockQuantity: 8,
    maxCapacity: 10,
    category: ProductCategory.drinks,
    rowLabel: 'A',
    columnNumber: 1,
    slotWidth: 1,
    iconKey: 'water_drop',
  ),
  const Product(
    id: 2,
    name: 'Cola',
    priceCents: 180,
    stockQuantity: 5,
    maxCapacity: 8,
    category: ProductCategory.drinks,
    rowLabel: 'A',
    columnNumber: 2,
    slotWidth: 1,
    iconKey: 'local_drink',
  ),
  const Product(
    id: 3,
    name: 'Eistee',
    priceCents: 160,
    stockQuantity: 4,
    maxCapacity: 8,
    category: ProductCategory.drinks,
    rowLabel: 'B',
    columnNumber: 1,
    slotWidth: 1,
    iconKey: 'local_drink',
  ),
  const Product(
    id: 4,
    name: 'Schokoriegel',
    priceCents: 110,
    stockQuantity: 9,
    maxCapacity: 12,
    category: ProductCategory.snacksBars,
    rowLabel: 'C',
    columnNumber: 1,
    slotWidth: 1,
    iconKey: 'fastfood',
  ),
  const Product(
    id: 5,
    name: 'Chips',
    priceCents: 220,
    stockQuantity: 3,
    maxCapacity: 6,
    category: ProductCategory.chips,
    rowLabel: 'C',
    columnNumber: 4,
    slotWidth: 2,
    iconKey: 'lunch_dining',
  ),
  const Product(
    id: 6,
    name: 'Kekse',
    priceCents: 140,
    stockQuantity: 6,
    maxCapacity: 10,
    category: ProductCategory.sweetsCookies,
    rowLabel: 'D',
    columnNumber: 2,
    slotWidth: 1,
    iconKey: 'cookie',
  ),
  const Product(
    id: 7,
    name: 'Mints',
    priceCents: 90,
    stockQuantity: 10,
    maxCapacity: 15,
    category: ProductCategory.knabberMints,
    rowLabel: 'E',
    columnNumber: 3,
    slotWidth: 1,
    iconKey: 'icecream',
  ),
  const Product(
    id: 8,
    name: 'Protein Bar',
    priceCents: 250,
    stockQuantity: 2,
    maxCapacity: 8,
    category: ProductCategory.fitness,
    rowLabel: 'F',
    columnNumber: 1,
    slotWidth: 1,
    iconKey: 'fitness_center',
  ),
];
