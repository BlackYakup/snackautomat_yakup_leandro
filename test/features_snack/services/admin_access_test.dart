import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/admin_access.dart';

const _pinFieldKey = ValueKey('admin-pin-field');
const _adminTestScreenKey = ValueKey('admin-test-screen');

Future<void> _pumpAdminLauncher(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appLightTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                await openAdminArea(
                  context,
                  adminScreenBuilder: (_) => const Scaffold(
                    key: _adminTestScreenKey,
                    body: Center(child: Text('Adminbereich geöffnet')),
                  ),
                );
              },
              child: const Text('Admin öffnen'),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _openPinDialog(WidgetTester tester) async {
  await tester.tap(find.text('Admin öffnen'));
  await tester.pumpAndSettle();

  expect(find.byType(AlertDialog), findsOneWidget);
}

InputDecoration _pinDecoration(WidgetTester tester) {
  return tester.widget<TextField>(find.byKey(_pinFieldKey)).decoration!;
}

void main() {
  testWidgets(
    'falscher PIN bleibt im Dialog und zeigt einen roten Fehlerzustand',
    (tester) async {
      await _pumpAdminLauncher(tester);
      await _openPinDialog(tester);

      await tester.enterText(find.byKey(_pinFieldKey), '0000');
      await tester.tap(find.text('Öffnen'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Falsche PIN. Bitte erneut versuchen.'), findsOneWidget);

      final decoration = _pinDecoration(tester);
      final errorBorder = decoration.focusedErrorBorder! as OutlineInputBorder;

      expect(errorBorder.borderSide.color, AdminColors.danger);
      expect(errorBorder.borderSide.width, 2);
    },
  );

  testWidgets('neue Eingabe entfernt den vorherigen Fehlerzustand', (
    tester,
  ) async {
    await _pumpAdminLauncher(tester);
    await _openPinDialog(tester);

    await tester.enterText(find.byKey(_pinFieldKey), '0000');
    await tester.tap(find.text('Öffnen'));
    await tester.pump();

    expect(find.text('Falsche PIN. Bitte erneut versuchen.'), findsOneWidget);

    await tester.enterText(find.byKey(_pinFieldKey), '1');
    await tester.pump();

    expect(find.text('Falsche PIN. Bitte erneut versuchen.'), findsNothing);
    expect(_pinDecoration(tester).errorText, isNull);

    final focusedBorder =
        _pinDecoration(tester).focusedBorder! as OutlineInputBorder;

    expect(focusedBorder.borderSide.color, AdminColors.accent);
  });

  testWidgets('korrekter PIN zeigt Erfolg und öffnet danach den Adminbereich', (
    tester,
  ) async {
    await _pumpAdminLauncher(tester);
    await _openPinDialog(tester);

    await tester.enterText(find.byKey(_pinFieldKey), kDefaultAdminPin);
    await tester.tap(find.text('Öffnen'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('PIN korrekt.'), findsOneWidget);

    final focusedBorder =
        _pinDecoration(tester).focusedBorder! as OutlineInputBorder;

    expect(focusedBorder.borderSide.color, AdminColors.success);
    expect(focusedBorder.borderSide.width, 2);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(_adminTestScreenKey), findsOneWidget);
  });

  testWidgets('falscher PIN erzeugt keine SnackBar hinter dem Dialog', (
    tester,
  ) async {
    await _pumpAdminLauncher(tester);
    await _openPinDialog(tester);

    await tester.enterText(find.byKey(_pinFieldKey), '0000');
    await tester.tap(find.text('Öffnen'));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Falsche PIN. Bitte erneut versuchen.'), findsOneWidget);
  });
}
