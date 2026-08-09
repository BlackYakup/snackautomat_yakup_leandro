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

class _CatalogFilterDropdown<T> extends StatelessWidget {
  const _CatalogFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: const TextStyle(
            color: AdminColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CategoryProductSection extends StatelessWidget {
  const _CategoryProductSection({
    required this.category,
    required this.products,
    required this.placed,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
  });

  final ProductCategory category;
  final List<Product> products;
  final List<PlacedProduct> placed;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onDelete;
  final ValueChanged<Product> onView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                productCategoryLabel(category),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AdminColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${products.length}',
                  style: const TextStyle(
                    color: AdminColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              const minCardWidth = 175.0;
              final columns = (constraints.maxWidth / (minCardWidth + spacing))
                  .floor()
                  .clamp(2, 6);
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: products.map((product) {
                  return SizedBox(
                    width: cardWidth,
                    child: _ProductCatalogCard(
                      product: product,
                      slotsLabel: assignedSlotsLabel(product, placed),
                      onEdit: () => onEdit(product),
                      onDelete: () => onDelete(product),
                      onView: () => onView(product),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProductCatalogCard extends StatelessWidget {
  const _ProductCatalogCard({
    required this.product,
    required this.slotsLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
  });

  final Product product;
  final String slotsLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final hasModel =
        product.modelPath != null && product.modelPath!.isNotEmpty;
    final widthLabel =
        product.slotWidth == 2 ? '2 Slots (E–F)' : '1 Slot (A–D)';
    final subtitle = '$widthLabel · $slotsLabel';

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ProductVisualAvatar(product: product, size: 56),
            ),
            if (hasModel) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: () {
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
                  icon: const Icon(Icons.view_in_ar_outlined, size: 16),
                  label: const Text('3D'),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AdminColors.textMuted,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatCents(product.priceCents),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _CatalogTextAction(
                  label: 'Bearbeiten',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
                const SizedBox(width: 12),
                _CatalogTextAction(
                  label: 'Löschen',
                  icon: Icons.delete_outline,
                  onPressed: onDelete,
                  color: AdminColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton(
                onPressed: onView,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.textPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Anzeigen',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogTextAction extends StatelessWidget {
  const _CatalogTextAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = AdminColors.textSecondary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.onSave,
    this.product,
  });

  final Product? product;
  final Future<void> Function(Product product) onSave;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _maxCapacityController;

  late ProductCategory _category;
  late int _slotWidth;
  String? _imagePath;
  String? _modelPath;
  String? _modelPart;
  List<String> _availableModelParts = [];
  String? _iconKey;
  bool _isSaving = false;
  bool _isModelUploading = false;
  bool _hideModelPreview = false;
  int _formStep = 0;

  @override
  void initState() {
    super.initState();
    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : (product.priceCents / 100).toStringAsFixed(2),
    );
    _maxCapacityController = TextEditingController(
      text: '${product?.maxCapacity ?? 10}',
    );

    _category = product?.category ?? ProductCategory.snacksBars;
    _slotWidth = product?.slotWidth ?? 1;
    _imagePath = product?.imagePath;
    _modelPath = product?.modelPath;
    _modelPart = product?.modelPart;
    _iconKey = product?.iconKey ?? 'fastfood';

    if (_modelPath != null) {
      _loadModelParts(_modelPath!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _maxCapacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewProduct = _buildPreviewProduct();
    final steps = ['Basis', 'Darstellung'];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AdminColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product == null
                              ? 'Neues Produkt anlegen'
                              : 'Produkt bearbeiten',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Katalogprodukt ohne Slot-Position',
                          style: TextStyle(color: AdminColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ProductVisualAvatar(
                    product: previewProduct,
                    size: 56,
                    preferModelPreview: _formStep == 1 &&
                        !_hideModelPreview &&
                        previewProduct.modelPath != null &&
                        previewProduct.modelPath!.isNotEmpty,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(steps.length, (index) {
                  final isActive = index == _formStep;
                  final isDone = index < _formStep;

                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _formStep = index),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AdminColors.accent.withValues(alpha: 0.14)
                                    : AdminColors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isActive
                                      ? AdminColors.accent.withValues(alpha: 0.4)
                                      : AdminColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}. ${steps[index]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isActive || isDone
                                        ? AdminColors.accent
                                        : AdminColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (index < steps.length - 1) const SizedBox(width: 8),
                      ],
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _formStep == 0
                      ? _buildBasicStep()
                      : _buildVisualStep(previewProduct),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AdminColors.border)),
              ),
              child: Row(
                children: [
                  if (_formStep > 0)
                    AdminSecondaryButton(
                      label: 'Zurück',
                      icon: Icons.arrow_back,
                      onPressed: _isSaving
                          ? null
                          : () => setState(() => _formStep -= 1),
                    ),
                  const Spacer(),
                  AdminSecondaryButton(
                    label: 'Abbrechen',
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  if (_formStep < 1)
                    AdminPrimaryButton(
                      label: 'Weiter',
                      icon: Icons.arrow_forward,
                      onPressed: _isSaving ? null : _nextStep,
                    )
                  else
                    AdminPrimaryButton(
                      label: 'Speichern',
                      icon: Icons.check,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _submit,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Produktname'),
          onChanged: (_) => setState(() {}),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name erforderlich';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _priceController,
          decoration: const InputDecoration(labelText: 'Preis in Euro'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          validator: (value) {
            final parsed = _parseEuroToCents(value ?? '');
            if (parsed == null || parsed <= 0) {
              return 'Gültigen Preis eingeben';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        DropdownMenu<ProductCategory>(
          initialSelection: _category,
          label: const Text('Kategorie'),
          dropdownMenuEntries: ProductCategory.values
              .map(
                (category) => DropdownMenuEntry(
                  value: category,
                  label: productCategoryLabel(category),
                ),
              )
              .toList(),
          onSelected: (value) {
            if (value != null) {
              setState(() => _category = value);
            }
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _maxCapacityController,
          decoration: const InputDecoration(
            labelText: 'Max. Kapazität im Automat',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            final capacity = int.tryParse(value ?? '');
            if (capacity == null || capacity < 1) {
              return 'Mindestens 1';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Slot-Breite',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AdminChipButton(
                label: '1 Slot (A–D)',
                selected: _slotWidth == 1,
                onPressed: () => setState(() => _slotWidth = 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AdminChipButton(
                label: '2 Slots (E–F)',
                selected: _slotWidth == 2,
                onPressed: () => setState(() => _slotWidth = 2),
              ),
            ),
          ],
        ),
        if (widget.product == null && (_slotWidth != 1 && _slotWidth != 2))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Bitte Slot-Breite wählen.',
              style: TextStyle(color: AdminColors.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _mergeDiscoveredParts(List<String> parts) async {
    if (!mounted || parts.isEmpty) {
      return;
    }

    final merged = ModelPartsHelper.merge(_availableModelParts, parts);

    if (listEquals(merged, _availableModelParts)) {
      return;
    }

    setState(() {
      _availableModelParts = merged;

      if (_modelPart == null || !_availableModelParts.contains(_modelPart)) {
        _modelPart = ObjModelParser.resolvePartName(
          _availableModelParts,
          _modelPart ?? _availableModelParts.first,
        );
      }
    });
  }

  Widget _buildVisualStep(Product previewProduct) {
    final hasModel = previewProduct.modelPath != null &&
        previewProduct.modelPath!.isNotEmpty;
    final showPartPicker = !_hideModelPreview &&
        hasModel &&
        ModelPartsHelper.hasMultipleParts(_availableModelParts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isModelUploading) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircularProgressIndicator(color: AdminColors.accent),
                  SizedBox(height: 12),
                  Text(
                    '3D-Modell wird vorbereitet...',
                    style: TextStyle(color: AdminColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ] else if (showPartPicker) ...[
          ModelPartPicker(
            modelPath: previewProduct.modelPath!,
            parts: _availableModelParts,
            selectedPart: _modelPart,
            onPartSelected: (part) => setState(() => _modelPart = part),
            onPartsAvailable: _mergeDiscoveredParts,
          ),
        ] else if (hasModel && _hideModelPreview) ...[
          const Center(child: ProductModelBadge(size: 200)),
        ] else if (hasModel) ...[
          Center(
            child: ProductModelPreview(
              key: ValueKey('${previewProduct.modelPath}|${_modelPart ?? ''}'),
              modelPath: previewProduct.modelPath!,
              size: 200,
              selectedPart: _modelPart,
              knownParts: _availableModelParts,
              onPartsAvailable: _mergeDiscoveredParts,
            ),
          ),
          if (_availableModelParts.length == 1) ...[
            const SizedBox(height: 8),
            const Text(
              'Einzelnes 3D-Objekt erkannt.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
            ),
          ],
        ] else ...[
          Center(
            child: ProductVisualAvatar(product: previewProduct, size: 96),
          ),
        ],
        if (_modelPath != null) ...[
          const SizedBox(height: 8),
          Text(
            '3D-Modell: ${_modelPath!.split(Platform.pathSeparator).last}'
            '${_modelPart != null ? ' · Teil: $_modelPart' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
        if (_imagePath != null) ...[
          const SizedBox(height: 8),
          Text(
            'Bild: ${_imagePath!.split(Platform.pathSeparator).last}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: AdminSecondaryButton(
                label: 'Bild hochladen',
                icon: Icons.upload_file,
                onPressed: _pickImage,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AdminSecondaryButton(
                label: 'Bild entfernen',
                icon: Icons.hide_image_outlined,
                onPressed: _imagePath == null
                    ? null
                    : () => setState(() => _imagePath = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AdminSecondaryButton(
                label: '3D-Modell hochladen',
                icon: Icons.view_in_ar_outlined,
                onPressed: _pickModel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AdminSecondaryButton(
                label: '3D-Modell entfernen',
                icon: Icons.layers_clear_outlined,
                onPressed: _modelPath == null
                    ? null
                    : () async {
                        await _discardStagingModel(_modelPath);
                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _modelPath = null;
                          _modelPart = null;
                          _availableModelParts = [];
                        });
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Unterstützte 3D-Formate: GLB, GLTF, OBJ (mit MTL/Texturen im gleichen Ordner)',
          style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        const Text(
          'Icon-Fallback (wenn kein Bild/3D)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: productIconOptions.entries.map((entry) {
            final isSelected = _iconKey == entry.key;

            return InkWell(
              onTap: () => setState(() => _iconKey = entry.key),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? AdminColors.accentGradient
                      : AdminColors.cardGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AdminColors.accent
                        : AdminColors.border,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AdminColors.accent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  entry.value,
                  color: isSelected ? Colors.white : AdminColors.textSecondary,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_slotWidth != 1 && _slotWidth != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Slot-Breite wählen.')),
      );
      return;
    }

    setState(() => _formStep += 1);
  }

  Product _buildPreviewProduct() {
    return Product(
      id: widget.product?.id,
      name: _nameController.text.isEmpty ? 'Vorschau' : _nameController.text,
      priceCents: _parseEuroToCents(_priceController.text) ?? 100,
      maxCapacity: int.tryParse(_maxCapacityController.text) ?? 10,
      category: _category,
      slotWidth: _slotWidth,
      imagePath: _imagePath,
      modelPath: _modelPath,
      modelPart: _modelPart,
      iconKey: _iconKey,
    );
  }

  Future<void> _loadModelParts(String path) async {
    final parsed = await ObjModelParser.extractObjectNames(path);

    if (!mounted) {
      return;
    }

    setState(() {
      _availableModelParts = parsed;

      if (_modelPart != null &&
          _modelPart!.isNotEmpty &&
          !_availableModelParts
              .any((part) => part.toLowerCase() == _modelPart!.toLowerCase())) {
        _availableModelParts = ModelPartsHelper.merge(
          _availableModelParts,
          [_modelPart!],
        );
      }

      if (_availableModelParts.isNotEmpty) {
        _modelPart = ObjModelParser.resolvePartName(
          _availableModelParts,
          _modelPart ?? _availableModelParts.first,
        );
      }
    });
  }

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['glb', 'gltf', 'obj'],
      allowMultiple: false,
    );

    final path = result?.files.single.path;

    if (path == null) {
      return;
    }

    setState(() => _isModelUploading = true);

    try {
      await _discardStagingModel(_modelPath);

      final persisted =
          await ProductAssetStorage.ensureModelForPreview(path);

      if (!mounted) {
        return;
      }

      setState(() {
        _modelPath = persisted;
        _modelPart = null;
        _availableModelParts = [];
      });

      await _loadModelParts(persisted);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('3D-Upload fehlgeschlagen: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isModelUploading = false);
      }
    }
  }

  Future<void> _discardStagingModel(String? path) async {
    final originalPath = widget.product?.modelPath;

    if (path == null || path == originalPath) {
      return;
    }

    await ProductAssetStorage.deleteManagedAsset(path);
    LocalFileCache.invalidate(path);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    final path = result?.files.single.path;

    if (path != null) {
      setState(() => _imagePath = path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _formStep = 0);
      return;
    }

    if (_slotWidth != 1 && _slotWidth != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Slot-Breite wählen.')),
      );
      setState(() => _formStep = 0);
      return;
    }

    final maxCapacity = int.parse(_maxCapacityController.text);
    final priceCents = _parseEuroToCents(_priceController.text);

    if (priceCents == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _hideModelPreview = true;
    });

    try {
      final persistedImage =
          await ProductAssetStorage.persistImagePath(_imagePath);
      var persistedModel =
          await ProductAssetStorage.persistModelPath(_modelPath);

      persistedModel = await ProductAssetStorage.finalizeModelSelection(
        modelPath: persistedModel,
        modelPart: _modelPart,
        availableParts: _availableModelParts,
      );

      final previousModelPath = widget.product?.modelPath;
      if (previousModelPath != null &&
          previousModelPath.isNotEmpty &&
          previousModelPath != persistedModel) {
        await ProductAssetStorage.deleteManagedAsset(previousModelPath);
      }

      LocalFileCache.invalidate(persistedImage);
      LocalFileCache.invalidate(persistedModel);

      final product = Product(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        priceCents: priceCents,
        maxCapacity: maxCapacity,
        category: _category,
        slotWidth: _slotWidth,
        imagePath: persistedImage,
        modelPath: persistedModel,
        modelPart: _modelPart,
        iconKey: _iconKey,
      );

      await widget.onSave(product);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $error')),
        );
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  int? _parseEuroToCents(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);

    if (value == null) {
      return null;
    }

    return (value * 100).round();
  }
}
