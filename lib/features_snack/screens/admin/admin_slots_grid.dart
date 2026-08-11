part of 'admin_slots_panel.dart';

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

