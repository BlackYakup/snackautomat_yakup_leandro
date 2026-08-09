import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';

enum AdminSection {
  coinInventory,
  productRefill,
  slots,
  products,
}

extension AdminSectionLabels on AdminSection {
  String get title {
    switch (this) {
      case AdminSection.coinInventory:
        return 'Münzbestand';
      case AdminSection.productRefill:
        return 'Auffüllen';
      case AdminSection.slots:
        return 'Slots';
      case AdminSection.products:
        return 'Produkte';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminSection.coinInventory:
        return Icons.toll_outlined;
      case AdminSection.productRefill:
        return Icons.inventory_2_outlined;
      case AdminSection.slots:
        return Icons.grid_view_outlined;
      case AdminSection.products:
        return Icons.fastfood_outlined;
    }
  }
}

class AdminHeader extends StatelessWidget {
  const AdminHeader({
    required this.section,
    super.key,
  });

  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminColors.headerBackground,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Zurück',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: AdminColors.textPrimary),
          ),
          const SizedBox(width: 4),
          Text(
            'Adminbereich: ${section.title}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    required this.selectedSection,
    required this.onSectionSelected,
    super.key,
  });

  final AdminSection selectedSection;
  final ValueChanged<AdminSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AdminColors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          ...AdminSection.values.map((section) {
            final isSelected = section == selectedSection;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSectionSelected(section),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AdminColors.sidebarActive
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          section.icon,
                          color: isSelected
                              ? AdminColors.accent
                              : AdminColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          section.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isSelected
                                ? AdminColors.textPrimary
                                : AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
