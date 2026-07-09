import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/db_creater.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/product_repository.dart';
import 'package:sqflite/sqflite.dart';

const coinDenominationsCents = [5, 10, 20, 50, 100, 200];

final databaseProvider = FutureProvider<Database>((ref) {
  return DbCreater.instance.database;
});

final productRepositoryProvider = FutureProvider<ProductRepository>((ref) async {
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
      final products = await repository.getProducts();

      if (products.isNotEmpty) {
        return products;
      }
    } catch (_) {
      // Temporär für UI-Test: Falls DB leer/noch nicht bereit ist.
    }

    return _demoProducts;
  }

  Future<void> increaseStock(Product product) async {
    await _changeStock(product, 1);
  }

  Future<void> decreaseStockForAdmin(Product product) async {
    await _changeStock(product, -1);
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

    final updatedProduct = products[index].copyWith(
      stockQuantity: newStock,
    );

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
    } catch (_) {
      // Temporär für UI-Test: UI bleibt nutzbar, auch wenn DB-Speichern scheitert.
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
    this.currentSlotInput = '',
    this.selectedSlotCode,
    this.selectedProduct,
    this.insertedAmountCents = 0,
    this.insertedCoins = const <int, int>{},
    this.outputProduct,
    this.outputChange = const <int, int>{},
    this.statusMessage = 'Bitte Produktposition eingeben.',
    this.coinInventory = const <int, int>{
      5: 20,
      10: 20,
      20: 20,
      50: 10,
      100: 10,
      200: 5,
    },
  });

  final String currentSlotInput;
  final String? selectedSlotCode;
  final Product? selectedProduct;
  final int insertedAmountCents;
  final Map<int, int> insertedCoins;
  final Product? outputProduct;
  final Map<int, int> outputChange;
  final String statusMessage;
  final Map<int, int> coinInventory;

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
  }) {
    return VendingSessionState(
      currentSlotInput: currentSlotInput ?? this.currentSlotInput,
      selectedSlotCode: clearSelectedSlotCode
          ? null
          : selectedSlotCode ?? this.selectedSlotCode,
      selectedProduct:
          clearSelectedProduct ? null : selectedProduct ?? this.selectedProduct,
      insertedAmountCents:
          insertedAmountCents ?? this.insertedAmountCents,
      insertedCoins: insertedCoins ?? this.insertedCoins,
      outputProduct:
          clearOutputProduct ? null : outputProduct ?? this.outputProduct,
      outputChange: outputChange ?? this.outputChange,
      statusMessage: statusMessage ?? this.statusMessage,
      coinInventory: coinInventory ?? this.coinInventory,
    );
  }
}

class VendingSessionNotifier extends Notifier<VendingSessionState> {
  Timer? _slotInputTimer;

  @override
  VendingSessionState build() {
    ref.onDispose(() {
      _slotInputTimer?.cancel();
    });

    return const VendingSessionState();
  }

  void pressSlotKey(String key) {
    final normalizedKey = key.toUpperCase();

    if (_isRowKey(normalizedKey)) {
      _setSlotInput(normalizedKey);
      return;
    }

    if (_isDigitKey(normalizedKey)) {
      final currentInput = state.currentSlotInput;

      if (currentInput.isEmpty || !_isRowKey(currentInput[0])) {
        state = state.copyWith(
          statusMessage: 'Bitte zuerst A bis F eingeben.',
        );
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

    state = state.copyWith(
      statusMessage: 'Ungültige Taste.',
    );
  }

  void clearSlotInput() {
    _slotInputTimer?.cancel();

    state = state.copyWith(
      currentSlotInput: '',
      clearSelectedSlotCode: true,
      clearSelectedProduct: true,
      statusMessage: 'Bitte Produktposition eingeben.',
    );
  }

  void backspaceSlotInput() {
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
    final slotCode = state.currentSlotInput.toUpperCase();

    if (slotCode.isEmpty) {
      state = state.copyWith(
        statusMessage: 'Bitte Produktposition eingeben.',
      );
      return;
    }

    selectProductBySlot(slotCode);
  }

  void selectProductBySlot(String slotCode) {
    final parsedSlot = _parseSlotCode(slotCode);

    if (parsedSlot == null) {
      state = state.copyWith(
        clearSelectedSlotCode: true,
        clearSelectedProduct: true,
        statusMessage: 'Ungültiger Slot: $slotCode',
      );
      return;
    }

    final products = ref.read(productControllerProvider).value ?? const <Product>[];
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
    if (product.isSoldOut) {
      state = state.copyWith(
        selectedSlotCode:
            selectedSlotCode ?? '${product.rowLabel}${product.columnNumber}',
        selectedProduct: product,
        statusMessage: 'Dieses Produkt ist ausverkauft.',
      );
      return;
    }

    final slotCode = selectedSlotCode ?? '${product.rowLabel}${product.columnNumber}';

    state = state.copyWith(
      currentSlotInput: slotCode,
      selectedSlotCode: slotCode,
      selectedProduct: product,
      clearOutputProduct: true,
      outputChange: const <int, int>{},
      statusMessage: '${product.name} ausgewählt.',
    );
  }

  void insertCoin(int denominationCents) {
    final insertedCoins = Map<int, int>.from(state.insertedCoins);
    insertedCoins[denominationCents] =
        (insertedCoins[denominationCents] ?? 0) + 1;

    state = state.copyWith(
      insertedAmountCents: state.insertedAmountCents + denominationCents,
      insertedCoins: insertedCoins,
      clearOutputProduct: true,
      outputChange: const <int, int>{},
      statusMessage: '${formatCents(denominationCents)} eingeworfen.',
    );
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
      outputChange: state.insertedCoins,
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

    final changeCoins = _calculateChange(changeAmount, availableCoins);

    if (changeCoins == null) {
      state = state.copyWith(
        statusMessage: 'Wechselgeld nicht möglich.',
      );
      return;
    }

    final productWasUpdated = await ref
        .read(productControllerProvider.notifier)
        .decreaseStockAfterPurchase(currentProduct);

    if (!productWasUpdated) {
      state = state.copyWith(statusMessage: 'Produkt ist nicht mehr verfügbar.');
      return;
    }

    final newCoinInventory = _subtractCoinMap(availableCoins, changeCoins);

    state = VendingSessionState(
      coinInventory: newCoinInventory,
      outputProduct: currentProduct,
      outputChange: changeCoins,
      statusMessage:
          '${currentProduct.name} ausgegeben. Wechselgeld: ${formatCents(changeAmount)}.',
    );
  }

  void addCoinsToInventory(int denominationCents, int quantity) {
    final coinInventory = Map<int, int>.from(state.coinInventory);
    coinInventory[denominationCents] =
        (coinInventory[denominationCents] ?? 0) + quantity;

    state = state.copyWith(
      coinInventory: coinInventory,
      statusMessage:
          '$quantity x ${formatCents(denominationCents)} aufgefüllt.',
    );
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

  _ParsedSlot? _parseSlotCode(String slotCode) {
    final normalizedSlotCode = slotCode.toUpperCase();

    if (normalizedSlotCode.length < 2 || normalizedSlotCode.length > 3) {
      return null;
    }

    final rowLabel = normalizedSlotCode[0];

    if (!_isRowKey(rowLabel)) {
      return null;
    }

    final columnText = normalizedSlotCode.substring(1);
    final columnNumber = int.tryParse(columnText);

    if (columnNumber == null || columnNumber < 1 || columnNumber > 10) {
      return null;
    }

    return _ParsedSlot(
      rowLabel: rowLabel,
      columnNumber: columnNumber,
    );
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

  Map<int, int>? _calculateChange(
    int changeAmountCents,
    Map<int, int> availableCoins,
  ) {
    var remainingAmount = changeAmountCents;
    final changeCoins = <int, int>{};

    for (final denomination in coinDenominationsCents.reversed) {
      final availableQuantity = availableCoins[denomination] ?? 0;

      if (availableQuantity == 0) {
        continue;
      }

      final neededQuantity = remainingAmount ~/ denomination;
      final usedQuantity = neededQuantity < availableQuantity
          ? neededQuantity
          : availableQuantity;

      if (usedQuantity > 0) {
        changeCoins[denomination] = usedQuantity;
        remainingAmount -= usedQuantity * denomination;
      }
    }

    if (remainingAmount != 0) {
      return null;
    }

    return changeCoins;
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

class _ParsedSlot {
  const _ParsedSlot({
    required this.rowLabel,
    required this.columnNumber,
  });

  final String rowLabel;
  final int columnNumber;

  String get code => '$rowLabel$columnNumber';
}

String formatCents(int cents) {
  final euros = cents ~/ 100;
  final remainingCents = cents % 100;

  return '$euros,${remainingCents.toString().padLeft(2, '0')} Euro';
}

final _demoProducts = <Product>[
  const Product(
    id: 1,
    name: 'Wasser',
    priceCents: 120,
    stockQuantity: 8,
    category: ProductCategory.drinks,
    rowLabel: 'A',
    columnNumber: 1,
    slotWidth: 1,
  ),
  const Product(
    id: 2,
    name: 'Cola',
    priceCents: 180,
    stockQuantity: 5,
    category: ProductCategory.drinks,
    rowLabel: 'A',
    columnNumber: 2,
    slotWidth: 1,
  ),
  const Product(
    id: 3,
    name: 'Eistee',
    priceCents: 160,
    stockQuantity: 4,
    category: ProductCategory.drinks,
    rowLabel: 'B',
    columnNumber: 1,
    slotWidth: 1,
  ),
  const Product(
    id: 4,
    name: 'Schokoriegel',
    priceCents: 110,
    stockQuantity: 9,
    category: ProductCategory.snacksBars,
    rowLabel: 'C',
    columnNumber: 1,
    slotWidth: 1,
  ),
  const Product(
    id: 5,
    name: 'Chips',
    priceCents: 220,
    stockQuantity: 3,
    category: ProductCategory.chips,
    rowLabel: 'C',
    columnNumber: 4,
    slotWidth: 2,
  ),
  const Product(
    id: 6,
    name: 'Kekse',
    priceCents: 140,
    stockQuantity: 6,
    category: ProductCategory.sweetsCookies,
    rowLabel: 'D',
    columnNumber: 2,
    slotWidth: 1,
  ),
  const Product(
    id: 7,
    name: 'Mints',
    priceCents: 90,
    stockQuantity: 10,
    category: ProductCategory.knabberMints,
    rowLabel: 'E',
    columnNumber: 3,
    slotWidth: 1,
  ),
  const Product(
    id: 8,
    name: 'Protein Bar',
    priceCents: 250,
    stockQuantity: 2,
    category: ProductCategory.fitness,
    rowLabel: 'F',
    columnNumber: 1,
    slotWidth: 1,
  ),
];
