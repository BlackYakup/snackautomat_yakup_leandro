part of 'provider_library.dart';

mixin _VendingSessionPayment on _VendingSessionSlotInput, _VendingSessionCoinPersist {
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
}
