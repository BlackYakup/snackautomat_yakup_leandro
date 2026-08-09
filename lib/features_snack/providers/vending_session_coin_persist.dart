part of 'provider_library.dart';

mixin _VendingSessionCoinPersist on _VendingSessionFields {
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

}
