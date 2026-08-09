part of 'provider_library.dart';

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

