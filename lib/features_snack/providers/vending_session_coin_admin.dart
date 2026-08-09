part of 'provider_library.dart';

mixin _VendingSessionCoinAdmin on _VendingSessionCoinPersist {
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
}
