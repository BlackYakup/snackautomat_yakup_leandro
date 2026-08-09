import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/admin_access.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/change_output.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/control_panel.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/product_area.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/product_output.dart';

class VendingMachineScreen extends ConsumerWidget {
  const VendingMachineScreen({super.key, this.show3dToggle = false});

  /// Eck-Taste „3D“ zum Zurückwechseln (Startbildschirm behält die Ansicht).
  final bool show3dToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(placedProductsProvider);
    final session = ref.watch(vendingSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snackautomat'),
        actions: [
          IconButton(
            tooltip: 'Admin',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: session.phase != VendingMachinePhase.ready
                ? null
                : () {
                    if (show3dToggle) {
                      // 3D-Ansicht darunter hält die Sperre — Admin über Startbildschirm öffnen.
                      Navigator.of(context).pop('admin');
                    } else {
                      openAdminArea(context);
                    }
                  },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          productsAsync.when(
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
          if (show3dToggle)
            Positioned(
              top: 10,
              left: 10,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  customBorder: const CircleBorder(),
                  child: const Tooltip(
                    message: 'Zur 3D-Ansicht',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xCC1A1E24),
                              border: Border.fromBorderSide(
                                BorderSide(
                                  color: Color(0x8C4A5560),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.view_in_ar_rounded,
                              color: Colors.white54,
                              size: 22,
                            ),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '3D',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
