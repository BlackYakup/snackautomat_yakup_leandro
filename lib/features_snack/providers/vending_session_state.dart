part of 'provider_library.dart';

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

