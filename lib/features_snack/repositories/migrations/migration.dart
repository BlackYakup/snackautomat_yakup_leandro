import 'package:sqflite/sqflite.dart';

abstract class Migration {
  const Migration();

  int get version;

  Future<void> up(Database db);
}

Future<Set<String>> getTableColumnNames(Database db, String tableName) async {
  final columns = await db.rawQuery('PRAGMA table_info("$tableName")');
  return columns.map((row) => row['name'] as String).toSet();
}
