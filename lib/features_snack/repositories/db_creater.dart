import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbCreater {
  static final DbCreater instance = DbCreater._();

  DbCreater._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(databasePath, "snackautomat.db");

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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