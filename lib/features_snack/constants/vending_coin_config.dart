const coinDenominationsCents = [5, 10, 20, 50, 100, 200];
const coinCassetteCapacity = 200;

const defaultCoinInventory = <int, int>{
  5: 30,
  10: 20,
  20: 20,
  50: 30,
  100: 20,
  200: 10,
};

const defaultCoinSurplus = <int, int>{
  5: 4,
  10: 0,
  20: 0,
  50: 0,
  100: 0,
  200: 0,
};

const defaultCoinEarnedSurplus = <int, int>{
  5: 0,
  10: 0,
  20: 0,
  50: 0,
  100: 0,
  200: 0,
};

const defaultCoinOwnCoins = <int, int>{
  5: 34,
  10: 20,
  20: 20,
  50: 30,
  100: 20,
  200: 10,
};

const defaultCoinTargetStock = <int, int>{
  5: 30,
  10: 20,
  20: 20,
  50: 30,
  100: 20,
  200: 10,
};

String formatCents(int cents) {
  final euros = cents ~/ 100;
  final remainingCents = cents % 100;

  return '$euros,${remainingCents.toString().padLeft(2, '0')} Euro';
}
