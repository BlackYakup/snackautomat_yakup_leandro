import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class Migration001InitialSchema extends Migration {
  const Migration001InitialSchema();

  @override 
  int get version => 1;

  @override
  Future<void> up(Database db) async {
    await db.execute("""
      CREATE TABLE product(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price_cents INTEGER NOT NULL,
        slot_number INTEGER NOT NULL,
        stock_quantity INTEGER NOT NULL
      );
    """);

    await db.execute("""
      CREATE TABLE coin_inventory(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        denomination_cents INTEGER NOT NULL UNIQUE,
        quantity INTEGER NOT NULL
      );
    """);

    await db.execute("""
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        amount_paid_cents INTEGER NOT NULL,
        change_given_cents INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(product_id) REFERENCES product(id)
      );
    """);
  }
}