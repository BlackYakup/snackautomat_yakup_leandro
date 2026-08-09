import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_visual.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_widgets.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/double_slot_layout.dart';

const _rowLabels = ['A', 'B', 'C', 'D', 'E', 'F'];
const _columnCount = 10;

class AdminSlotsPanel extends ConsumerWidget {
  const AdminSlotsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placedAsync = ref.watch(placedProductsProvider);
    final catalogAsync = ref.watch(productControllerProvider);

    return placedAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AdminColors.accent),
      ),
      error: (error, _) => AdminEmptyState(
        icon: Icons.error_outline,
        title: 'Slots nicht verfügbar',
        message: '$error',
      ),
      data: (placed) {
        final catalog = catalogAsync.value ?? const <Product>[];

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final catalogPane = _ProductCatalogPane(
              catalog: catalog,
              onTapAssign: (product) => _pickSlotForProduct(
                context,
                ref,
                product: product,
                placed: placed,
              ),
            );
            final gridPane = _SlotsGridPane(
              placed: placed,
              onEmptyTap: (row, col) => _openAssignDialog(
                context,
                ref,
                rowLabel: row,
                columnNumber: col,
                catalog: catalog,
              ),
              onEmptyDrop: (row, col, product) => _openAssignDialog(
                context,
                ref,
                rowLabel: row,
                columnNumber: col,
                catalog: catalog,
                preselected: product,
              ),
              onOccupiedTap: (entry) => _openOccupiedDialog(
                context,
                ref,
                entry,
              ),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Slot-Belegung',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Produkte aus der Liste auf einen Slot ziehen oder antippen. '
                    'Beim Zuweisen den Automatenpreis festlegen — Kunden müssen '
                    'diesen Betrag vor der Ausgabe bezahlen (Münzen → Kassette).',
                    style: TextStyle(color: AdminColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 280, child: catalogPane),
                        const SizedBox(width: 16),
                        Expanded(child: gridPane),
                      ],
                    )
                  else ...[
                    catalogPane,
                    const SizedBox(height: 16),
                    gridPane,
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'A–B: Getränke (1 Slot) · C–D: Nicht-Getränke (1 Slot) · E–F: Doppel-Slots',
                    style: TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickSlotForProduct(
    BuildContext context,
    WidgetRef ref, {
    required Product product,
    required List<PlacedProduct> placed,
  }) async {
    final free = <({String row, int col})>[];
    for (final row in _rowLabels) {
      if (!isPlacementAllowed(
        category: product.category,
        slotWidth: product.slotWidth,
        rowLabel: row,
      )) {
        continue;
      }
      var col = 1;
      while (col <= _columnCount) {
        final occupied = placed.any(
          (p) =>
              p.rowLabel.toUpperCase() == row &&
              col >= p.columnNumber &&
              col < p.columnNumber + p.slotWidth,
        );
        if (!occupied) {
          if (product.slotWidth == 1 ||
              (col + product.slotWidth - 1 <= _columnCount &&
                  !placed.any(
                    (p) =>
                        p.rowLabel.toUpperCase() == row &&
                        p.columnNumber == col + 1,
                  ))) {
            free.add((row: row, col: col));
          }
        }
        col += 1;
      }
    }

    if (free.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kein freier Slot für ${product.name} verfügbar.',
            ),
          ),
        );
      }
      return;
    }

    final choice = await showDialog<({String row, int col})>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Slot für ${product.name}'),
        children: [
          for (final s in free.take(40))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s),
              child: Text('${s.row}${s.col}'),
            ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    await _openAssignDialog(
      context,
      ref,
      rowLabel: choice.row,
      columnNumber: choice.col,
      catalog: [product],
      preselected: product,
    );
  }

  Future<void> _openAssignDialog(
    BuildContext context,
    WidgetRef ref, {
    required String rowLabel,
    required int columnNumber,
    required List<Product> catalog,
    Product? preselected,
  }) async {
    final candidates = catalog.where((product) {
      if (product.id == null) return false;
      return isPlacementAllowed(
        category: product.category,
        slotWidth: product.slotWidth,
        rowLabel: rowLabel,
      );
    }).toList();

    if (preselected != null &&
        !candidates.any((p) => p.id == preselected.id)) {
      if (isPlacementAllowed(
        category: preselected.category,
        slotWidth: preselected.slotWidth,
        rowLabel: rowLabel,
      )) {
        candidates.insert(0, preselected);
      }
    }

    if (candidates.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kein Katalogprodukt für Reihe $rowLabel verfügbar.',
            ),
          ),
        );
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _AssignSlotDialog(
          rowLabel: rowLabel,
          columnNumber: columnNumber,
          candidates: candidates,
          initialProduct: preselected ?? candidates.first,
          onAssign: (product, stock, priceCents) async {
            try {
              await ref.read(productControllerProvider.notifier).assignToSlot(
                    product: product,
                    rowLabel: rowLabel,
                    columnNumber: columnNumber,
                    stockQuantity: stock,
                    maxCapacity: product.maxCapacity,
                    priceCents: priceCents,
                  );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${product.name} auf $rowLabel$columnNumber · '
                      '${formatCents(priceCents)}',
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

  Future<void> _openOccupiedDialog(
    BuildContext context,
    WidgetRef ref,
    PlacedProduct placed,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _OccupiedSlotDialog(
          placed: placed,
          onClear: () async {
            final slotId = placed.slotId;
            if (slotId == null) return;
            await ref.read(productControllerProvider.notifier).clearSlot(slotId);
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Slot ${placed.slotCode} freigegeben.'),
                ),
              );
            }
          },
          onRefill: () async {
            Navigator.of(dialogContext).pop();
            await _openRefillDialog(context, ref, placed);
          },
          onSavePrice: (priceCents) async {
            await ref.read(productControllerProvider.notifier).saveProduct(
                  placed.product.copyWith(priceCents: priceCents),
                );
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Preis für ${placed.name}: ${formatCents(priceCents)}',
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _openRefillDialog(
    BuildContext context,
    WidgetRef ref,
    PlacedProduct placed,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SlotRefillDialog(
          placed: placed,
          onRefill: (amount) async {
            await ref
                .read(placedProductsProvider.notifier)
                .increaseStockBy(placed, amount);
          },
          onRefillToMax: () async {
            await ref.read(placedProductsProvider.notifier).refillToMax(placed);
          },
          onSetStock: (stock) async {
            await ref
                .read(placedProductsProvider.notifier)
                .setStockQuantity(placed, stock);
          },
        );
      },
    );
  }
}

class _ProductCatalogPane extends StatelessWidget {
  const _ProductCatalogPane({
    required this.catalog,
    required this.onTapAssign,
  });

  final List<Product> catalog;
  final ValueChanged<Product> onTapAssign;

  @override
  Widget build(BuildContext context) {
    final products = catalog.where((p) => p.id != null).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Produktliste',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Auf Slot ziehen oder antippen',
            style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 480,
            child: products.isEmpty
                ? const Center(
                    child: Text(
                      'Keine Produkte im Katalog.',
                      style: TextStyle(color: AdminColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _DraggableCatalogItem(
                        product: product,
                        onTap: () => onTapAssign(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DraggableCatalogItem extends StatelessWidget {
  const _DraggableCatalogItem({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: const Color(0xFFF7F5FB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ProductVisualAvatar(product: product, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      formatCents(product.priceCents),
                      style: const TextStyle(
                        color: AdminColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.drag_indicator, color: AdminColors.textMuted),
            ],
          ),
        ),
      ),
    );

    return Draggable<Product>(
      data: product,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 240, child: child),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }
}

class _SlotsGridPane extends StatelessWidget {
  const _SlotsGridPane({
    required this.placed,
    required this.onEmptyTap,
    required this.onEmptyDrop,
    required this.onOccupiedTap,
  });

  final List<PlacedProduct> placed;
  final void Function(String row, int column) onEmptyTap;
  final void Function(String row, int column, Product product) onEmptyDrop;
  final ValueChanged<PlacedProduct> onOccupiedTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E4F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'Raster A–F × 1–10',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 520,
            child: Column(
              children: _rowLabels.map((rowLabel) {
                return Expanded(
                  child: _SlotsGridRow(
                    rowLabel: rowLabel,
                    placed: placed,
                    onEmptyTap: (column) => onEmptyTap(rowLabel, column),
                    onEmptyDrop: (column, product) =>
                        onEmptyDrop(rowLabel, column, product),
                    onOccupiedTap: onOccupiedTap,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotsGridRow extends StatelessWidget {
  const _SlotsGridRow({
    required this.rowLabel,
    required this.placed,
    required this.onEmptyTap,
    required this.onEmptyDrop,
    required this.onOccupiedTap,
  });

  final String rowLabel;
  final List<PlacedProduct> placed;
  final ValueChanged<int> onEmptyTap;
  final void Function(int column, Product product) onEmptyDrop;
  final ValueChanged<PlacedProduct> onOccupiedTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      SizedBox(
        width: 28,
        child: Center(
          child: Text(
            rowLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    ];

    var column = 1;
    while (column <= _columnCount) {
      final entry = _productStartingAt(rowLabel, column);

      if (entry == null) {
        final col = column;
        children.add(
          Expanded(
            child: _EmptySlotCell(
              slotLabel: displaySlotCode(rowLabel: rowLabel, columnNumber: col),
              onTap: () => onEmptyTap(col),
              onAccept: (product) => onEmptyDrop(col, product),
              accepts: (product) => isPlacementAllowed(
                category: product.category,
                slotWidth: product.slotWidth,
                rowLabel: rowLabel,
              ),
            ),
          ),
        );
        column += 1;
      } else {
        children.add(
          Expanded(
            flex: entry.slotWidth,
            child: _OccupiedSlotCell(
              placed: entry,
              onTap: () => onOccupiedTap(entry),
            ),
          ),
        );
        column += entry.slotWidth;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: children),
    );
  }

  PlacedProduct? _productStartingAt(String rowLabel, int columnNumber) {
    for (final entry in placed) {
      if (entry.rowLabel.toUpperCase() == rowLabel &&
          entry.columnNumber == columnNumber) {
        return entry;
      }
    }
    return null;
  }
}

class _EmptySlotCell extends StatelessWidget {
  const _EmptySlotCell({
    required this.slotLabel,
    required this.onTap,
    required this.onAccept,
    required this.accepts,
  });

  final String slotLabel;
  final VoidCallback onTap;
  final ValueChanged<Product> onAccept;
  final bool Function(Product product) accepts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: DragTarget<Product>(
        onWillAcceptWithDetails: (details) => accepts(details.data),
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidate, rejected) {
          final hovering = candidate.isNotEmpty;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: hovering
                      ? AdminColors.accent.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hovering
                        ? AdminColors.accent
                        : AdminColors.border.withValues(alpha: 0.8),
                    width: hovering ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slotLabel,
                        style: const TextStyle(
                          color: AdminColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        hovering ? Icons.download : Icons.add,
                        size: 16,
                        color: AdminColors.accent.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OccupiedSlotCell extends StatelessWidget {
  const _OccupiedSlotCell({
    required this.placed,
    required this.onTap,
  });

  final PlacedProduct placed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: placed.priceCents <= 0
                    ? const Color(0xFFFF4D6D)
                    : AdminColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: placed.slotWidth == 2 ? 170 : 90,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductVisualAvatar(product: placed.product, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      displaySlotCode(
                        rowLabel: placed.rowLabel,
                        columnNumber: placed.columnNumber,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      placed.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      formatCents(placed.priceCents),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: placed.priceCents <= 0
                            ? const Color(0xFFFF4D6D)
                            : AdminColors.accent,
                      ),
                    ),
                    Text(
                      '${placed.stockQuantity}/${placed.maxCapacity}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignSlotDialog extends StatefulWidget {
  const _AssignSlotDialog({
    required this.rowLabel,
    required this.columnNumber,
    required this.candidates,
    required this.initialProduct,
    required this.onAssign,
  });

  final String rowLabel;
  final int columnNumber;
  final List<Product> candidates;
  final Product initialProduct;
  final Future<void> Function(Product product, int stock, int priceCents)
      onAssign;

  @override
  State<_AssignSlotDialog> createState() => _AssignSlotDialogState();
}

class _AssignSlotDialogState extends State<_AssignSlotDialog> {
  Product? _selected;
  late final TextEditingController _stockController;
  late final TextEditingController _priceController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialProduct;
    _stockController = TextEditingController(
      text: '${_selected?.maxCapacity ?? 0}',
    );
    _priceController = TextEditingController(
      text: ((_selected?.priceCents ?? 100) / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slotLabel = '${widget.rowLabel}${widget.columnNumber}';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Produkt auf $slotLabel',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Automatenpreis festlegen — Kunden müssen diesen Betrag '
                'einzahlen, bevor das Produkt ausgegeben wird.',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownMenu<Product>(
                initialSelection: _selected,
                label: const Text('Produkt'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: widget.candidates
                    .map(
                      (product) => DropdownMenuEntry(
                        value: product,
                        label:
                            '${product.name} · ${formatCents(product.priceCents)}',
                      ),
                    )
                    .toList(),
                onSelected: (value) {
                  if (value == null) return;
                  setState(() {
                    _selected = value;
                    _stockController.text = '${value.maxCapacity}';
                    _priceController.text =
                        (value.priceCents / 100).toStringAsFixed(2);
                  });
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Automatenpreis (EUR)',
                  helperText: 'z. B. 1,60',
                  prefixText: '€ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: 'Startbestand',
                  helperText: _selected == null
                      ? null
                      : 'Max. ${_selected!.maxCapacity}',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AdminSecondaryButton(
                      label: 'Abbrechen',
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminPrimaryButton(
                      label: 'Zuweisen',
                      icon: Icons.check,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final product = _selected;
    if (product == null) return;

    final priceCents = _parseEuroToCents(_priceController.text);
    if (priceCents == null || priceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte einen gültigen Preis größer 0 eingeben.'),
        ),
      );
      return;
    }

    final stock = int.tryParse(_stockController.text) ?? 0;
    if (stock < 0 || stock > product.maxCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bestand muss zwischen 0 und ${product.maxCapacity} liegen.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    await widget.onAssign(product, stock, priceCents);
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

class _OccupiedSlotDialog extends StatefulWidget {
  const _OccupiedSlotDialog({
    required this.placed,
    required this.onClear,
    required this.onRefill,
    required this.onSavePrice,
  });

  final PlacedProduct placed;
  final Future<void> Function() onClear;
  final Future<void> Function() onRefill;
  final Future<void> Function(int priceCents) onSavePrice;

  @override
  State<_OccupiedSlotDialog> createState() => _OccupiedSlotDialogState();
}

class _OccupiedSlotDialogState extends State<_OccupiedSlotDialog> {
  late final TextEditingController _priceController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: (widget.placed.priceCents / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placed = widget.placed;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProductVisualAvatar(product: placed.product, size: 64),
              const SizedBox(height: 12),
              Text(
                placed.name,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Slot ${placed.slotCode} · Bestand ${placed.stockQuantity}/${placed.maxCapacity}',
                style: const TextStyle(color: AdminColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Automatenpreis (EUR)',
                  prefixText: '€ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AdminPrimaryButton(
                  label: 'Preis speichern',
                  icon: Icons.euro,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _savePrice,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: AdminPrimaryButton(
                  label: 'Auffüllen',
                  icon: Icons.add_box_outlined,
                  onPressed: widget.onRefill,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: AdminSecondaryButton(
                  label: 'Slot freigeben',
                  icon: Icons.clear_all,
                  onPressed: widget.onClear,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Schließen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePrice() async {
    final priceCents = _parseEuroToCents(_priceController.text);
    if (priceCents == null || priceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte einen gültigen Preis größer 0 eingeben.'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    await widget.onSavePrice(priceCents);
    if (mounted) setState(() => _isSaving = false);
  }
}

class _SlotRefillDialog extends StatefulWidget {
  const _SlotRefillDialog({
    required this.placed,
    required this.onRefill,
    required this.onRefillToMax,
    required this.onSetStock,
  });

  final PlacedProduct placed;
  final Future<void> Function(int amount) onRefill;
  final Future<void> Function() onRefillToMax;
  final Future<void> Function(int stock) onSetStock;

  @override
  State<_SlotRefillDialog> createState() => _SlotRefillDialogState();
}

class _SlotRefillDialogState extends State<_SlotRefillDialog> {
  late int _stock;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _stock = widget.placed.stockQuantity;
  }

  @override
  Widget build(BuildContext context) {
    final placed = widget.placed;
    final missing = placed.maxCapacity - _stock;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProductVisualAvatar(product: placed.product, size: 64),
              const SizedBox(height: 12),
              Text(
                placed.name,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Position ${placed.slotCode} · ${formatCents(placed.priceCents)}',
                style: const TextStyle(color: AdminColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                '$_stock von ${placed.maxCapacity}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                missing > 0
                    ? 'Noch $missing Stück bis voll'
                    : 'Slot ist voll befüllt',
                style: const TextStyle(color: AdminColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  AdminChipButton(
                    label: '+1',
                    selected: true,
                    onPressed: _isSaving || _stock >= placed.maxCapacity
                        ? null
                        : () => _applyRefill(1),
                  ),
                  AdminChipButton(
                    label: '+5',
                    selected: true,
                    onPressed: _isSaving || _stock >= placed.maxCapacity
                        ? null
                        : () => _applyRefill(5),
                  ),
                  AdminChipButton(
                    label: 'Voll auffüllen',
                    selected: true,
                    onPressed: _isSaving || _stock >= placed.maxCapacity
                        ? null
                        : _applyRefillToMax,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AdminSecondaryButton(
                      label: 'Abbrechen',
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminPrimaryButton(
                      label: 'Speichern',
                      icon: Icons.check,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _saveStock,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyRefill(int amount) async {
    setState(() => _isSaving = true);
    await widget.onRefill(amount);
    if (!mounted) return;
    setState(() {
      _stock = (_stock + amount).clamp(0, widget.placed.maxCapacity);
      _isSaving = false;
    });
  }

  Future<void> _applyRefillToMax() async {
    setState(() => _isSaving = true);
    await widget.onRefillToMax();
    if (!mounted) return;
    setState(() {
      _stock = widget.placed.maxCapacity;
      _isSaving = false;
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveStock() async {
    setState(() => _isSaving = true);
    await widget.onSetStock(_stock);
    if (mounted) Navigator.of(context).pop();
  }
}

int? _parseEuroToCents(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  final value = double.tryParse(normalized);
  if (value == null) return null;
  return (value * 100).round();
}
