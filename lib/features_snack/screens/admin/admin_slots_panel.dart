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


part 'admin_slots_catalog.dart';
part 'admin_slots_grid.dart';
part 'admin_slots_dialogs.dart';

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
