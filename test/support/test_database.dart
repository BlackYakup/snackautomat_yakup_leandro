import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openTestDatabase() async {
  sqfliteFfiInit();

  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      version: currentDatabaseVersion,
      onCreate: (database, version) async {
        await runMigrations(database, fromVersion: 0, toVersion: version);
      },
    ),
  );
}

Future<int> seedProduct(
  Database database, {
  String name = 'Testprodukt',
  int priceCents = 160,
  int stockQuantity = 3,
  int maxCapacity = 10,
  String category = 'snacks_bars',
  String rowLabel = 'C',
  int columnNumber = 4,
  int slotWidth = 1,
}) {
  return database.insert('product', {
    'name': name,
    'price_cents': priceCents,
    'stock_quantity': stockQuantity,
    'max_capacity': maxCapacity,
    'category': category,
    'row_label': rowLabel,
    'column_number': columnNumber,
    'slot_width': slotWidth,
  });
}
