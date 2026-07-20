import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class Migration005ProductModelPath extends Migration {
  const Migration005ProductModelPath();

  @override
  int get version => 5;

  @override
  Future<void> up(Database db) async {
    await db.execute('ALTER TABLE product ADD COLUMN model_path TEXT;');
  }
}
