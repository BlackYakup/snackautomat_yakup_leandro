import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_model_preview.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';

/// Teile-Auswahl mit Live-3D-Vorschau des gewählten Objekt-Teils.
class ModelPartPicker extends StatelessWidget {
  const ModelPartPicker({
    required this.modelPath,
    required this.parts,
    required this.selectedPart,
    required this.onPartSelected,
    this.onPartsAvailable,
    this.previewSize = 200,
    super.key,
  });

  final String modelPath;
  final List<String> parts;
  final String? selectedPart;
  final ValueChanged<String> onPartSelected;
  final ValueChanged<List<String>>? onPartsAvailable;
  final double previewSize;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    final activePart = selectedPart ?? parts.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ProductModelPreview(
            key: ValueKey('$modelPath|$activePart'),
            modelPath: modelPath,
            size: previewSize,
            selectedPart: activePart,
            knownParts: parts,
            onPartsAvailable: onPartsAvailable,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '3D-Teil auswählen (${parts.length} Objekte in der Datei)',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tippe ein Objekt an – die Vorschau zeigt nur dieses Teil.',
          style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AdminColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: parts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final part = parts[index];
                final isSelected = part == activePart;

                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: AdminColors.accent.withValues(alpha: 0.08),
                  leading: Icon(
                    Icons.view_in_ar_outlined,
                    color: isSelected
                        ? AdminColors.accent
                        : AdminColors.textMuted,
                  ),
                  title: Text(
                    part,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AdminColors.accent
                          : AdminColors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AdminColors.accent)
                      : null,
                  onTap: () => onPartSelected(part),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
