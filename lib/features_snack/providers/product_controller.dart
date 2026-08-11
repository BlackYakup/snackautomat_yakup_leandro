part of 'provider_library.dart';

class ProductController extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    try {
      final repository = await ref.watch(productRepositoryProvider.future);
      var products = await repository.getProducts();

      if (products.isEmpty) {
        await _seedCatalog(repository);
        products = await repository.getProducts();
      } else {
        await _ensureSlotsIfEmpty(repository, products);
        products = await repository.getProducts();
      }

      for (final product in products) {
        if (product.id != null && product.priceCents <= 0) {
          await repository.saveProduct(product.copyWith(priceCents: 150));
        }
      }
      products = await repository.getProducts();

      if (products.isNotEmpty) {
        return products;
      }
    } catch (error) {
      debugPrint('ProductController: Laden fehlgeschlagen: $error');
    }

    // Letzter Rückfall: in der DB befüllen, nicht nur im Speicher ohne Slots.
    try {
      final repository = await ref.read(productRepositoryProvider.future);
      await _seedCatalog(repository);
      final products = await repository.getProducts();
      if (products.isNotEmpty) return products;
    } catch (error) {
      debugPrint('ProductController: Fallback-Seed fehlgeschlagen: $error');
    }

    return _demoProducts;
  }

  /// Wenn Katalogprodukte existieren, aber keine Slots → Katalog-Slots nachziehen.
  Future<void> _ensureSlotsIfEmpty(
    ProductRepository repository,
    List<Product> products,
  ) async {
    final placed = await repository.getPlacedProducts();
    if (placed.isNotEmpty) return;

    debugPrint(
      'ProductController: ${products.length} Produkte ohne Slots — '
      'Slot-Belegung wird aus Katalog hergestellt.',
    );

    final seed = await ProductCatalogAssets.loadSeedData();
    if (seed.slotAssignments.isEmpty) {
      for (final demo in _demoPlacedProducts) {
        final match = products
            .where((p) => p.name == demo.product.name)
            .firstOrNull;
        if (match == null) continue;
        try {
          await repository.assignProductToSlot(
            product: match,
            rowLabel: demo.rowLabel,
            columnNumber: demo.columnNumber,
            stockQuantity: demo.stockQuantity,
            maxCapacity: demo.maxCapacity,
          );
        } catch (error) {
          debugPrint('Demo-Slot ${demo.slotCode}: $error');
        }
      }
      return;
    }

    final byName = <String, Product>{};
    for (final p in products) {
      byName.putIfAbsent(p.name, () => p);
    }

    for (final assignment in seed.slotAssignments) {
      final catalog = seed.products[assignment.productIndex];
      final match = byName[catalog.name];
      if (match == null) continue;
      try {
        await repository.assignProductToSlot(
          product: match,
          rowLabel: assignment.slot.rowLabel,
          columnNumber: assignment.slot.columnNumber,
          stockQuantity: assignment.slot.stockQuantity,
          maxCapacity: assignment.slot.maxCapacity,
        );
      } catch (error) {
        debugPrint('Slot-Repair ${assignment.slot.slotCode}: $error');
      }
    }
  }

  Future<void> _seedCatalog(ProductRepository repository) async {
    try {
      final seed = await ProductCatalogAssets.loadSeedData();
      if (seed.products.isEmpty) {
        for (final demo in _demoPlacedProducts) {
          await repository.saveProductAtSlot(
            PlacedProduct(
              product: demo.product.copyWith(id: null),
              slot: demo.slot.copyWith(id: null, productId: 0),
            ),
          );
        }
        return;
      }

      final insertedIds = <int>[];
      for (final product in seed.products) {
        final id = await repository.saveProduct(product.copyWith(id: null));
        insertedIds.add(id);
      }

      for (final assignment in seed.slotAssignments) {
        final productId = insertedIds[assignment.productIndex];
        final catalog = seed.products[assignment.productIndex];
        try {
          await repository.assignProductToSlot(
            product: catalog.copyWith(id: productId),
            rowLabel: assignment.slot.rowLabel,
            columnNumber: assignment.slot.columnNumber,
            stockQuantity: assignment.slot.stockQuantity,
            maxCapacity: assignment.slot.maxCapacity,
          );
        } catch (error) {
          debugPrint('Slot-Seed ${assignment.slot.slotCode}: $error');
        }
      }
    } catch (error) {
      debugPrint('ProductController: Katalog-Seed fehlgeschlagen: $error');
      for (final demo in _demoPlacedProducts) {
        try {
          await repository.saveProductAtSlot(
            PlacedProduct(
              product: demo.product.copyWith(id: null),
              slot: demo.slot.copyWith(id: null, productId: 0),
            ),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> saveProduct(Product product) async {
    final repository = await ref.read(productRepositoryProvider.future);
    await repository.saveProduct(product);
    LocalFileCache.invalidate(product.imagePath);
    LocalFileCache.invalidate(product.modelPath);
    await reloadProducts();
  }

  Future<void> savePlacedProduct(PlacedProduct placed) async {
    final repository = await ref.read(productRepositoryProvider.future);
    await repository.saveProductAtSlot(placed);
    LocalFileCache.invalidate(placed.imagePath);
    LocalFileCache.invalidate(placed.modelPath);
    await reloadProducts();
  }

  Future<void> deleteProduct(Product product) async {
    final productId = product.id;
    if (productId == null) {
      final products = state.value ?? const <Product>[];
      state = AsyncData(
        products.where((entry) => entry.name != product.name).toList(),
      );
      return;
    }

    try {
      final repository = await ref.read(productRepositoryProvider.future);
      await repository.deleteProduct(productId);
      await ProductAssetStorage.deleteAssetsForProduct(product);
      await reloadProducts();
    } catch (error) {
      debugPrint('ProductController: Löschen fehlgeschlagen: $error');
      await reloadProducts();
    }
  }

  Future<void> deletePlacedProduct(PlacedProduct placed) async {
    await deleteProduct(placed.product);
  }

  Future<void> reloadProducts() async {
    try {
      final repository = await ref.read(productRepositoryProvider.future);
      var products = await repository.getProducts();
      if (products.isEmpty) {
        await _seedCatalog(repository);
        products = await repository.getProducts();
      } else {
        await _ensureSlotsIfEmpty(repository, products);
        products = await repository.getProducts();
      }
      for (final product in products) {
        if (product.id != null && product.priceCents <= 0) {
          await repository.saveProduct(product.copyWith(priceCents: 150));
        }
      }
      products = await repository.getProducts();
      state = AsyncData(products.isEmpty ? _demoProducts : products);
      ref.invalidate(placedProductsProvider);
    } catch (error) {
      debugPrint('ProductController: Reload fehlgeschlagen: $error');
      state = AsyncData(state.value ?? _demoProducts);
    }
  }

  Future<void> assignToSlot({
    required Product product,
    required String rowLabel,
    required int columnNumber,
    required int stockQuantity,
    int? maxCapacity,
    int? existingSlotId,
    int? priceCents,
  }) async {
    final repository = await ref.read(productRepositoryProvider.future);
    var toPlace = product;
    if (priceCents != null && priceCents > 0) {
      toPlace = product.copyWith(priceCents: priceCents);
      await repository.saveProduct(toPlace);
    }
    await repository.assignProductToSlot(
      product: toPlace,
      rowLabel: rowLabel,
      columnNumber: columnNumber,
      stockQuantity: stockQuantity,
      maxCapacity: maxCapacity,
      existingSlotId: existingSlotId,
    );
    await reloadProducts();
  }

  Future<void> clearSlot(int slotId) async {
    final repository = await ref.read(productRepositoryProvider.future);
    await repository.clearSlot(slotId);
    ref.invalidate(placedProductsProvider);
  }
}

