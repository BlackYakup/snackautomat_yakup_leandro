import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_coin_inventory_panel.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_layout.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_product_refill_panel.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_products_panel.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  AdminSection _selectedSection = AdminSection.coinInventory;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: adminTheme(),
      child: Scaffold(
        backgroundColor: AdminColors.background,
        body: Row(
          children: [
            AdminSidebar(
              selectedSection: _selectedSection,
              onSectionSelected: (section) {
                setState(() => _selectedSection = section);
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminHeader(section: _selectedSection),
                  Expanded(
                    child: switch (_selectedSection) {
                      AdminSection.coinInventory =>
                        const AdminCoinInventoryPanel(),
                      AdminSection.productRefill =>
                        const AdminProductRefillPanel(),
                      AdminSection.products => const AdminProductsPanel(),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
