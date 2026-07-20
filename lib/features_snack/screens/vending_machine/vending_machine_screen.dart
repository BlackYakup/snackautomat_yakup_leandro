import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/admin_access.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/vending_hud_display.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/vending_input_panel.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/vending_product_panel.dart';

class VendingMachineScreen extends ConsumerWidget {
  const VendingMachineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snackautomat'),
        actions: [
          IconButton(
            tooltip: 'Admin',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => openAdminArea(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              constraints.maxWidth < 920 ? 920.0 : constraints.maxWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(
                      flex: 4,
                      child: VendingProductPanel(),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 360,
                      child: Column(
                        children: [
                          const VendingHudDisplay(),
                          const SizedBox(height: 8),
                          const Expanded(
                            child: VendingInputPanel(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
