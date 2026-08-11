part of 'admin_slots_panel.dart';

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

