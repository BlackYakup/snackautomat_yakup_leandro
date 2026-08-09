import 'package:snackautomat_yakup_leandro/features_snack/constants/vending_coin_config.dart';

class ChangeCalculator {
  const ChangeCalculator._();

  static Map<int, int>? calculate({
    required int changeCents,
    required Map<int, int> inventory,
  }) {
    if (changeCents < 0) {
      return null;
    }

    var remainingAmount = changeCents;
    final changeCoins = <int, int>{};

    for (final denomination in coinDenominationsCents.reversed) {
      final availableQuantity = inventory[denomination] ?? 0;

      if (availableQuantity <= 0) {
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

    return remainingAmount == 0 ? changeCoins : null;
  }
}
