import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_coin_inventory_panel.dart';
import 'package:sqflite/sqflite.dart';

import '../../../support/test_database.dart';

void main() {
  late Database database;

  setUp(() async {
    database = await openTestDatabase();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('Folgeaktionen erscheinen erst nach Kassette leeren', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWith((ref) async => database)],
        child: const MaterialApp(
          home: Scaffold(body: AdminCoinInventoryPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kassette leeren'), findsOneWidget);
    expect(find.text('Einnahmen abschöpfen'), findsNothing);
    expect(find.text('Wechselgeld-Rückführung'), findsNothing);

    await tester.ensureVisible(find.text('Kassette leeren'));
    await tester.tap(find.text('Kassette leeren'));
    await tester.pump();

    expect(find.text('Kassette leeren'), findsNothing);
    expect(find.text('Einnahmen abschöpfen'), findsOneWidget);
    expect(find.text('Wechselgeld-Rückführung'), findsOneWidget);
    expect(find.text('Abrechnung beenden'), findsOneWidget);
  });
}
