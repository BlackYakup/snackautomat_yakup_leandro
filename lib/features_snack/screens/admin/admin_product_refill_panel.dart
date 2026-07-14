import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_visual.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_widgets.dart';

const _rowLabels = ['A', 'B', 'C', 'D', 'E', 'F'];
const _columnCount = 10;

class AdminProductRefillPanel extends ConsumerWidget {
  const AdminProductRefillPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productControllerProvider);

    return productsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AdminColors.accent),
      ),
      error: (error, _) => AdminEmptyState(
        icon: Icons.error_outline,
        title: 'Raster nicht verfügbar',
        message: '$error',
      ),
      data: (products) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Produkt auffüllen',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Klicke auf ein Produkt im Raster, um den Bestand nachzufüllen.',
                style: TextStyle(color: AdminColors.textMuted),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E4F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Produkte',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          height: 520,
                          child: Column(
                            children: _rowLabels.map((rowLabel) {
                              return Expanded(
                                child: _RefillProductRow(
                                  rowLabel: rowLabel,
                                  products: products,
                                  onProductTap: (product) => _openRefillDialog(
                                    context,
                                    ref,
                                    product,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: const [
                  _LegendItem(
                    color: AdminColors.danger,
                    label: 'Niedrig – Nachfüllen nötig',
                  ),
                  _LegendItem(
                    color: AdminColors.warning,
                    label: 'Mittlerer Bestand',
                  ),
                  _LegendItem(
                    color: AdminColors.success,
                    label: 'Ausreichend befüllt',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRefillDialog(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _RefillDialog(
          product: product,
          onRefill: (amount) async {
            await ref
                .read(productControllerProvider.notifier)
                .increaseStockBy(product, amount);
          },
          onRefillToMax: () async {
            await ref
                .read(productControllerProvider.notifier)
                .refillToMax(product);
          },
          onSetStock: (stock) async {
            await ref
                .read(productControllerProvider.notifier)
                .setStockQuantity(product, stock);
          },
        );
      },
    );
  }
}

class _RefillProductRow extends StatelessWidget {
  const _RefillProductRow({
    required this.rowLabel,
    required this.products,
    required this.onProductTap,
  });

  final String rowLabel;
  final List<Product> products;
  final ValueChanged<Product> onProductTap;

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
      final product = _productStartingAt(rowLabel, column);

      if (product == null) {
        children.add(
          Expanded(
            child: _RefillEmptySlot(slotLabel: '$rowLabel$column'),
          ),
        );
        column += 1;
      } else {
        children.add(
          Expanded(
            flex: product.slotWidth,
            child: _RefillProductSlot(
              product: product,
              onTap: () => onProductTap(product),
            ),
          ),
        );
        column += product.slotWidth;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: children),
    );
  }

  Product? _productStartingAt(String rowLabel, int columnNumber) {
    for (final product in products) {
      if (product.rowLabel.toUpperCase() == rowLabel &&
          product.columnNumber == columnNumber) {
        return product;
      }
    }

    return null;
  }
}

class _RefillProductSlot extends StatelessWidget {
  const _RefillProductSlot({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slotLabel = '${product.rowLabel}${product.columnNumber}';
    final stockColor = _stockLevelColor(product);
    final needsRefill = product.stockQuantity <= 2;

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
                color: needsRefill
                    ? AdminColors.danger.withValues(alpha: 0.6)
                    : AdminColors.border,
                width: needsRefill ? 2 : 1,
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
                width: product.slotWidth == 2 ? 170 : 90,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductVisualAvatar(product: product, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      slotLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      formatCents(product.priceCents),
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      '${product.stockQuantity} von ${product.maxCapacity}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: stockColor,
                      ),
                    ),
                    if (needsRefill)
                      Text(
                        'Nachfüllen',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: stockColor,
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

class _RefillEmptySlot extends StatelessWidget {
  const _RefillEmptySlot({required this.slotLabel});

  final String slotLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminColors.border.withValues(alpha: 0.7)),
        ),
        child: Center(
          child: Text(
            slotLabel,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AdminColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

Color _stockLevelColor(Product product) {
  if (product.isSoldOut || product.stockQuantity <= 2) {
    return AdminColors.danger;
  }

  if (product.stockQuantity <= product.maxCapacity * 0.5) {
    return AdminColors.warning;
  }

  return AdminColors.success;
}

class _RefillDialog extends StatefulWidget {
  const _RefillDialog({
    required this.product,
    required this.onRefill,
    required this.onRefillToMax,
    required this.onSetStock,
  });

  final Product product;
  final Future<void> Function(int amount) onRefill;
  final Future<void> Function() onRefillToMax;
  final Future<void> Function(int stock) onSetStock;

  @override
  State<_RefillDialog> createState() => _RefillDialogState();
}

class _RefillDialogState extends State<_RefillDialog> {
  late int _stock;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _stock = widget.product.stockQuantity;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final slotLabel = '${product.rowLabel}${product.columnNumber}';
    final stockColor = _stockLevelColor(product.copyWith(stockQuantity: _stock));
    final missing = product.maxCapacity - _stock;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProductVisualAvatar(product: product, size: 72),
              const SizedBox(height: 14),
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Position $slotLabel',
                style: const TextStyle(color: AdminColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                '$_stock von ${product.maxCapacity}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: stockColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                missing > 0
                    ? 'Noch $missing Stück bis voll'
                    : 'Slot ist voll befüllt',
                style: const TextStyle(color: AdminColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundActionButton(
                    icon: Icons.remove,
                    onPressed: _isSaving || _stock <= 0
                        ? null
                        : () => setState(() => _stock -= 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '$_stock',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _RoundActionButton(
                    icon: Icons.add,
                    highlighted: true,
                    onPressed: _isSaving || _stock >= product.maxCapacity
                        ? null
                        : () => setState(() => _stock += 1),
                  ),
                ],
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
                    onPressed: _isSaving || _stock >= product.maxCapacity
                        ? null
                        : () => _applyRefill(1),
                  ),
                  AdminChipButton(
                    label: '+5',
                    selected: true,
                    onPressed: _isSaving || _stock >= product.maxCapacity
                        ? null
                        : () => _applyRefill(5),
                  ),
                  AdminChipButton(
                    label: 'Voll auffüllen',
                    selected: true,
                    onPressed: _isSaving || _stock >= product.maxCapacity
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

    if (!mounted) {
      return;
    }

    setState(() {
      _stock = (_stock + amount).clamp(0, widget.product.maxCapacity);
      _isSaving = false;
    });
  }

  Future<void> _applyRefillToMax() async {
    setState(() => _isSaving = true);

    await widget.onRefillToMax();

    if (!mounted) {
      return;
    }

    setState(() {
      _stock = widget.product.maxCapacity;
      _isSaving = false;
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveStock() async {
    setState(() => _isSaving = true);

    await widget.onSetStock(_stock);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? AdminColors.accent.withValues(alpha: 0.15)
          : AdminColors.surfaceHighlight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null
                ? AdminColors.textMuted
                : highlighted
                    ? AdminColors.accent
                    : AdminColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
