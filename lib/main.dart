import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/db_creater.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/vending_machine_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DbCreater.instance.database;

  runApp(const ProviderScope(child: SnackLY()));
}

class SnackLY extends StatelessWidget {
  const SnackLY ({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VendingMachineScreen(),
    );
  }
}

