import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class Migration006ProductModelPart extends Migration {
  const Migration006ProductModelPart();

  @override
  int get version => 6;

  @override
  Future<void> up(Database db) async {
    await db.execute('ALTER TABLE product ADD COLUMN model_part TEXT;');
  }
}
