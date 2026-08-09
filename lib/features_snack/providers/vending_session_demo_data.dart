part of 'provider_library.dart';

final _demoPlacedProducts = <PlacedProduct>[
  PlacedProduct(
    product: const Product(
      id: 1,
      name: 'Wasser',
      priceCents: 120,
      maxCapacity: 10,
      category: ProductCategory.drinks,
      slotWidth: 1,
      iconKey: 'water_drop',
    ),
    slot: const ProductSlot(
      productId: 1,
      rowLabel: 'A',
      columnNumber: 1,
      stockQuantity: 8,
      maxCapacity: 10,
    ),
  ),
  PlacedProduct(
    product: const Product(
      id: 2,
      name: 'Cola',
      priceCents: 180,
      maxCapacity: 8,
      category: ProductCategory.drinks,
      slotWidth: 1,
      iconKey: 'local_drink',
    ),
    slot: const ProductSlot(
      productId: 2,
      rowLabel: 'A',
      columnNumber: 2,
      stockQuantity: 5,
      maxCapacity: 8,
    ),
  ),
  PlacedProduct(
    product: const Product(
      id: 3,
      name: 'Schokoriegel',
      priceCents: 110,
      maxCapacity: 12,
      category: ProductCategory.snacksBars,
      slotWidth: 1,
      iconKey: 'fastfood',
    ),
    slot: const ProductSlot(
      productId: 3,
      rowLabel: 'C',
      columnNumber: 1,
      stockQuantity: 9,
      maxCapacity: 12,
    ),
  ),
  PlacedProduct(
    product: const Product(
      id: 4,
      name: 'Chips',
      priceCents: 220,
      maxCapacity: 6,
      category: ProductCategory.chips,
      slotWidth: 1,
      iconKey: 'lunch_dining',
    ),
    slot: const ProductSlot(
      productId: 4,
      rowLabel: 'C',
      columnNumber: 4,
      stockQuantity: 3,
      maxCapacity: 6,
    ),
  ),
];

final _demoProducts =
    _demoPlacedProducts.map((placed) => placed.product).toList();
