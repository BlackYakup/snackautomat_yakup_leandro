import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_001_initial_schema.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_002_product_layout_fields.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_003_indexes_and_constraints.dart';
import 'package:sqflite/sqflite.dart';

final List<Migration> allMigrations = <Migration>[
  const Migration001InitialSchema(),
  const Migration002ProductLayoutFields(),
  const Migration003IndexesAndConstraints()
]..sort((a, b) => a.version.compareTo(b.version));

int get currentDatabaseVersion => allMigrations.last.version;

Future<void> runMigrations(
  Database db, {
    required int fromVersion,
    required int toVersion
  }) async {
    for (final migration in allMigrations) {
      if (migration.version > fromVersion && migration.version <= toVersion) {
        await migration.up(db);
      }
    }
  }