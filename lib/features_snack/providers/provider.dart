import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/db_creater.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/product_repository.dart';
import 'package:sqflite/sqflite.dart';

final databaseProvider = FutureProvider<Database>((ref) {
  return DbCreater.instance.database;
});

final productRepositoryProvider = FutureProvider<ProductRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ProductRepository(db);
});

final productListProvider = FutureProvider<List<Product>>((ref) async {
  final repository = await ref.watch(productRepositoryProvider.future);
  return repository.getProducts();
});

final vendingSessionProvider = NotifierProvider<VendingSessionNotifier, VendingSessionState>(VendingSessionNotifier.new);

class VendingSessionState {
  const VendingSessionState({
    this.insertedCents = 0,
    this.selectedProduct
  });

  final int insertedCents;
  final Product? selectedProduct;

  VendingSessionState copyWith({
    int? insertedCents,
    Product? selectedProduct
  }) {
    return VendingSessionState(
      insertedCents: insertedCents ?? this.insertedCents,
      selectedProduct: selectedProduct ?? this.selectedProduct
    );
  }
}

class VendingSessionNotifier extends Notifier<VendingSessionState> {
  @override
  VendingSessionState build() {
    return const VendingSessionState();
  }

  void insertMoney(int cents) {
    state = state.copyWith(insertedCents: state.insertedCents + cents);
  }

  void selectProduct(Product product) {
    state = state.copyWith(selectedProduct: product);
  }

  void reset() {
    state = const VendingSessionState();
  }
}