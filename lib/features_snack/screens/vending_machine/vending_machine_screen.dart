import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/admin_access.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/change_output.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/control_panel.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/product_area.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/product_output.dart';

class VendingMachineScreen extends ConsumerWidget {
  const VendingMachineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productControllerProvider);
    final session = ref.watch(vendingSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snackautomat'),
        actions: [
          IconButton(
            tooltip: 'Admin',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: session.phase == VendingMachinePhase.ready
                ? () => openAdminArea(context)
                : null,
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Fehler beim Laden: $error')),
        data: (products) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth < 920
                  ? 920.0
                  : constraints.maxWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              Expanded(
                                child: ProductArea(
                                  products: products,
                                  selectedProduct: session.selectedProduct,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ProductOutput(session: session),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 360,
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: ControlPanel(session: session),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ChangeOutput(session: session),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
