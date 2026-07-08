import 'package:sqflite/sqflite.dart';

abstract class Migration {
  const Migration();

  int get version;

  Future<void> up(Database db);
}