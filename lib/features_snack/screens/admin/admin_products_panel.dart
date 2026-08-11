import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_model_preview.dart';
import 'package:snackautomat_yakup_leandro/features_snack/widgets/model_part_picker.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_visual.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/obj_model_parser.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/local_file_cache.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/product_asset_storage.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_widgets.dart';


part 'admin_products_filters.dart';
part 'admin_products_form_dialog.dart';

enum _PriceFilter { all, under1, oneToTwo, over2 }

class AdminProductsPanel extends ConsumerStatefulWidget {
  const AdminProductsPanel({super.key});

  @override
  ConsumerState<AdminProductsPanel> createState() => _AdminProductsPanelState();
}

class _AdminProductsPanelState extends ConsumerState<AdminProductsPanel> {
  final _searchController = TextEditingController();
  ProductCategory? _categoryFilter;
  _PriceFilter _priceFilter = _PriceFilter.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productControllerProvider);
    final placedAsync = ref.watch(placedProductsProvider);
    final placed = placedAsync.value ?? const <PlacedProduct>[];

    return productsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AdminColors.accent),
      ),
      error: (error, _) => AdminEmptyState(
        icon: Icons.error_outline,
        title: 'Katalog nicht verfügbar',
        message: '$error',
      ),
      data: (products) {
        final grouped = _groupByCategory(products);
        final hasResults = grouped.values.any((list) => list.isNotEmpty);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vending-Produktkatalog',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                        ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth > 720
                                ? 280
                                : constraints.maxWidth,
                            child: AdminSearchField(
                              controller: _searchController,
                              hint: 'Suchen...',
                              onChanged: (value) {
                                setState(
                                  () => _searchQuery = value.trim().toLowerCase(),
                                );
                              },
                            ),
                          ),
                          _CatalogFilterDropdown<ProductCategory?>(
                            label: 'Alle Kategorien',
                            value: _categoryFilter,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Alle Kategorien'),
                              ),
                              ...ProductCategory.values.map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(productCategoryLabel(category)),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _categoryFilter = value);
                            },
                          ),
                          _CatalogFilterDropdown<_PriceFilter>(
                            label: 'Preis',
                            value: _priceFilter,
                            items: const [
                              DropdownMenuItem(
                                value: _PriceFilter.all,
                                child: Text('Preis (Min – Max)'),
                              ),
                              DropdownMenuItem(
                                value: _PriceFilter.under1,
                                child: Text('Unter 1,00 €'),
                              ),
                              DropdownMenuItem(
                                value: _PriceFilter.oneToTwo,
                                child: Text('1,00 € – 2,00 €'),
                              ),
                              DropdownMenuItem(
                                value: _PriceFilter.over2,
                                child: Text('Über 2,00 €'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _priceFilter = value);
                              }
                            },
                          ),
                          AdminPrimaryButton(
                            label: 'Neues Produkt hinzufügen',
                            icon: Icons.add_rounded,
                            onPressed: () => _openProductDialog(context, ref),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: !hasResults
                  ? AdminEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: products.isEmpty
                          ? 'Noch keine Produkte'
                          : 'Keine Treffer',
                      message: products.isEmpty
                          ? 'Lege dein erstes Katalogprodukt mit Preis und Darstellung an.'
                          : 'Passe Suche oder Filter an.',
                      action: products.isEmpty
                          ? AdminPrimaryButton(
                              label: 'Produkt anlegen',
                              onPressed: () => _openProductDialog(context, ref),
                            )
                          : null,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                      children: [
                        for (final category in ProductCategory.values)
                          if (grouped[category]?.isNotEmpty ?? false)
                            _CategoryProductSection(
                              category: category,
                              products: grouped[category]!,
                              placed: placed,
                              onEdit: (product) => _openProductDialog(
                                context,
                                ref,
                                product: product,
                              ),
                              onDelete: (product) =>
                                  _confirmDelete(context, ref, product),
                              onView: (product) => _showProductDetail(
                                context,
                                product,
                                placed,
                              ),
                            ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Map<ProductCategory, List<Product>> _groupByCategory(List<Product> products) {
    final grouped = <ProductCategory, List<Product>>{};

    for (final category in ProductCategory.values) {
      final filtered = _filterAndSort(
        products.where((product) => product.category == category).toList(),
      );

      if (filtered.isNotEmpty) {
        grouped[category] = filtered;
      }
    }

    return grouped;
  }

  List<Product> _filterAndSort(List<Product> products) {
    var result = products.where((product) {
      if (_categoryFilter != null && product.category != _categoryFilter) {
        return false;
      }

      if (!_matchesPriceFilter(product)) {
        return false;
      }

      if (_searchQuery.isEmpty) {
        return true;
      }

      final haystack =
          '${product.name} ${productCategoryLabel(product.category)} '
                  '${product.slotWidth}'
              .toLowerCase();

      return haystack.contains(_searchQuery);
    }).toList();

    result.sort((a, b) => a.name.compareTo(b.name));

    return result;
  }

  bool _matchesPriceFilter(Product product) {
    switch (_priceFilter) {
      case _PriceFilter.all:
        return true;
      case _PriceFilter.under1:
        return product.priceCents < 100;
      case _PriceFilter.oneToTwo:
        return product.priceCents >= 100 && product.priceCents <= 200;
      case _PriceFilter.over2:
        return product.priceCents > 200;
    }
  }

  Future<void> _showProductDetail(
    BuildContext context,
    Product product,
    List<PlacedProduct> placed,
  ) async {
    final slotsLabel = assignedSlotsLabel(product, placed);
    final hasModel =
        product.modelPath != null && product.modelPath!.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProductVisualAvatar(
                    product: product,
                    size: 96,
                    preferModelPreview: hasModel,
                  ),
                  if (hasModel) ...[
                    const SizedBox(height: 10),
                    AdminSecondaryButton(
                      label: '3D-Vorschau öffnen',
                      icon: Icons.view_in_ar_outlined,
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        showProductModelPreviewDialog(
                          context: context,
                          modelPath: product.modelPath!,
                          selectedPart: product.modelPart,
                          knownParts: product.modelPath!
                                  .toLowerCase()
                                  .endsWith('.obj')
                              ? null
                              : const [],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${productCategoryLabel(product.category)} · '
                    '${product.slotWidth == 2 ? '2 Slots (E–F)' : '1 Slot (A–D)'}',
                    style: const TextStyle(color: AdminColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Slots: $slotsLabel',
                    style: const TextStyle(color: AdminColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    formatCents(product.priceCents),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Max. Kapazität: ${product.maxCapacity}',
                    style: const TextStyle(color: AdminColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AdminPrimaryButton(
                      label: 'Schließen',
                      icon: Icons.close,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? product,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return _ProductFormDialog(
          product: product,
          onSave: (savedProduct) async {
            try {
              await ref
                  .read(productControllerProvider.notifier)
                  .saveProduct(savedProduct);

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }

              await Future<void>.delayed(Duration.zero);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      product == null
                          ? 'Produkt erfolgreich angelegt.'
                          : 'Produkt erfolgreich aktualisiert.',
                    ),
                  ),
                );
              }
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fehler: $error')),
                );
              }
            }
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Produkt löschen'),
          content: Text(
            'Soll "${product.name}" dauerhaft aus dem Katalog entfernt werden?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.danger,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await ref.read(productControllerProvider.notifier).deleteProduct(product);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produkt gelöscht.')),
      );
    }
  }
}

String assignedSlotsLabel(Product product, List<PlacedProduct> placed) {
  final productId = product.id;
  if (productId == null) {
    return 'nicht zugewiesen';
  }

  final codes = placed
      .where((entry) => entry.id == productId)
      .map((entry) => entry.slotCode)
      .toList()
    ..sort();

  if (codes.isEmpty) {
    return 'nicht zugewiesen';
  }

  return codes.join(', ');
}
