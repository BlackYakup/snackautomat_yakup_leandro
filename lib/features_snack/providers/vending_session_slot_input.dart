part of 'provider_library.dart';

mixin _VendingSessionSlotInput on _VendingSessionHelpers {
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
}
