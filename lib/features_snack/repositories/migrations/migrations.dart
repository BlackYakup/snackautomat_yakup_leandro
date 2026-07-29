import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_001_initial_schema.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_002_product_layout_fields.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_003_indexes_and_constraints.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_004_product_visual_fields.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_005_product_model_path.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_006_product_model_part.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_007_coin_state_fields.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_008_coin_earned_surplus.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/migrations/migration_009_coin_own_quantity.dart';
import 'package:sqflite/sqflite.dart';

final List<Migration> allMigrations = <Migration>[
  const Migration001InitialSchema(),
  const Migration002ProductLayoutFields(),
  const Migration003IndexesAndConstraints(),
  const Migration004ProductVisualFields(),
  const Migration005ProductModelPath(),
  const Migration006ProductModelPart(),
  const Migration007CoinStateFields(),
  const Migration008CoinEarnedSurplus(),
  const Migration009CoinOwnQuantity(),
]..sort((a, b) => a.version.compareTo(b.version));

int get currentDatabaseVersion => allMigrations.last.version;

Future<void> runMigrations(
  Database db, {
  required int fromVersion,
  required int toVersion,
}) async {
  for (final migration in allMigrations) {
    if (migration.version > fromVersion && migration.version <= toVersion) {
      await migration.up(db);
    }
  }
}
