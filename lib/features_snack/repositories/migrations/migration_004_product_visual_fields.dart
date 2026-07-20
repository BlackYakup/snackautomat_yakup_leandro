import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class Migration004ProductVisualFields extends Migration {
  const Migration004ProductVisualFields();

  @override
  int get version => 4;

  @override
  Future<void> up(Database db) async {
    final columnNames = await getTableColumnNames(db, 'product');

    if (!columnNames.contains('max_capacity')) {
      await db.execute(
        'ALTER TABLE product ADD COLUMN max_capacity INTEGER NOT NULL DEFAULT 10;',
      );
    }

    if (!columnNames.contains('image_path')) {
      await db.execute('ALTER TABLE product ADD COLUMN image_path TEXT;');
    }

    if (!columnNames.contains('icon_key')) {
      await db.execute('ALTER TABLE product ADD COLUMN icon_key TEXT;');
    }
  }
}
