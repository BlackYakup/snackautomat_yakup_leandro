import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/database_factory_config.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migrations.dart';
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
    configureDatabaseFactory();

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, "snackautomat.db");

    debugPrint('SQLite-Datenbank: $path');

    return await openDatabase(
      path,
      version: currentDatabaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await runMigrations(
      db,
      fromVersion: 0,
      toVersion: version
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await runMigrations(
      db,
      fromVersion: oldVersion,
      toVersion: newVersion
    );
  }
}
