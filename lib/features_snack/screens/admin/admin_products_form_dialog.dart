part of 'admin_products_panel.dart';

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.onSave,
    this.product,
  });

  final Product? product;
  final Future<void> Function(Product product) onSave;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _maxCapacityController;

  late ProductCategory _category;
  late int _slotWidth;
  String? _imagePath;
  String? _modelPath;
  String? _modelPart;
  List<String> _availableModelParts = [];
  String? _iconKey;
  bool _isSaving = false;
  bool _isModelUploading = false;
  bool _hideModelPreview = false;
  int _formStep = 0;

  @override
  void initState() {
    super.initState();
    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : (product.priceCents / 100).toStringAsFixed(2),
    );
    _maxCapacityController = TextEditingController(
      text: '${product?.maxCapacity ?? 10}',
    );

    _category = product?.category ?? ProductCategory.snacksBars;
    _slotWidth = product?.slotWidth ?? 1;
    _imagePath = product?.imagePath;
    _modelPath = product?.modelPath;
    _modelPart = product?.modelPart;
    _iconKey = product?.iconKey ?? 'fastfood';

    if (_modelPath != null) {
      _loadModelParts(_modelPath!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _maxCapacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewProduct = _buildPreviewProduct();
    final steps = ['Basis', 'Darstellung'];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AdminColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product == null
                              ? 'Neues Produkt anlegen'
                              : 'Produkt bearbeiten',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Katalogprodukt ohne Slot-Position',
                          style: TextStyle(color: AdminColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ProductVisualAvatar(
                    product: previewProduct,
                    size: 56,
                    preferModelPreview: _formStep == 1 &&
                        !_hideModelPreview &&
                        previewProduct.modelPath != null &&
                        previewProduct.modelPath!.isNotEmpty,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(steps.length, (index) {
                  final isActive = index == _formStep;
                  final isDone = index < _formStep;

                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _formStep = index),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AdminColors.accent.withValues(alpha: 0.14)
                                    : AdminColors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isActive
                                      ? AdminColors.accent.withValues(alpha: 0.4)
                                      : AdminColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}. ${steps[index]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isActive || isDone
                                        ? AdminColors.accent
                                        : AdminColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (index < steps.length - 1) const SizedBox(width: 8),
                      ],
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _formStep == 0
                      ? _buildBasicStep()
                      : _buildVisualStep(previewProduct),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AdminColors.border)),
              ),
              child: Row(
                children: [
                  if (_formStep > 0)
                    AdminSecondaryButton(
                      label: 'Zurück',
                      icon: Icons.arrow_back,
                      onPressed: _isSaving
                          ? null
                          : () => setState(() => _formStep -= 1),
                    ),
                  const Spacer(),
                  AdminSecondaryButton(
                    label: 'Abbrechen',
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  if (_formStep < 1)
                    AdminPrimaryButton(
                      label: 'Weiter',
                      icon: Icons.arrow_forward,
                      onPressed: _isSaving ? null : _nextStep,
                    )
                  else
                    AdminPrimaryButton(
                      label: 'Speichern',
                      icon: Icons.check,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _submit,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Produktname'),
          onChanged: (_) => setState(() {}),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name erforderlich';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _priceController,
          decoration: const InputDecoration(labelText: 'Preis in Euro'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          validator: (value) {
            final parsed = _parseEuroToCents(value ?? '');
            if (parsed == null || parsed <= 0) {
              return 'Gültigen Preis eingeben';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        DropdownMenu<ProductCategory>(
          initialSelection: _category,
          label: const Text('Kategorie'),
          dropdownMenuEntries: ProductCategory.values
              .map(
                (category) => DropdownMenuEntry(
                  value: category,
                  label: productCategoryLabel(category),
                ),
              )
              .toList(),
          onSelected: (value) {
            if (value != null) {
              setState(() => _category = value);
            }
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _maxCapacityController,
          decoration: const InputDecoration(
            labelText: 'Max. Kapazität im Automat',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            final capacity = int.tryParse(value ?? '');
            if (capacity == null || capacity < 1) {
              return 'Mindestens 1';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Slot-Breite',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AdminChipButton(
                label: '1 Slot (A–D)',
                selected: _slotWidth == 1,
                onPressed: () => setState(() => _slotWidth = 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AdminChipButton(
                label: '2 Slots (E–F)',
                selected: _slotWidth == 2,
                onPressed: () => setState(() => _slotWidth = 2),
              ),
            ),
          ],
        ),
        if (widget.product == null && (_slotWidth != 1 && _slotWidth != 2))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Bitte Slot-Breite wählen.',
              style: TextStyle(color: AdminColors.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _mergeDiscoveredParts(List<String> parts) async {
    if (!mounted || parts.isEmpty) {
      return;
    }

    final merged = ModelPartsHelper.merge(_availableModelParts, parts);

    if (listEquals(merged, _availableModelParts)) {
      return;
    }

    setState(() {
      _availableModelParts = merged;

      if (_modelPart == null || !_availableModelParts.contains(_modelPart)) {
        _modelPart = ObjModelParser.resolvePartName(
          _availableModelParts,
          _modelPart ?? _availableModelParts.first,
        );
      }
    });
  }

  Widget _buildVisualStep(Product previewProduct) {
    final hasModel = previewProduct.modelPath != null &&
        previewProduct.modelPath!.isNotEmpty;
    final showPartPicker = !_hideModelPreview &&
        hasModel &&
        ModelPartsHelper.hasMultipleParts(_availableModelParts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isModelUploading) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircularProgressIndicator(color: AdminColors.accent),
                  SizedBox(height: 12),
                  Text(
                    '3D-Modell wird vorbereitet...',
                    style: TextStyle(color: AdminColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ] else if (showPartPicker) ...[
          ModelPartPicker(
            modelPath: previewProduct.modelPath!,
            parts: _availableModelParts,
            selectedPart: _modelPart,
            onPartSelected: (part) => setState(() => _modelPart = part),
            onPartsAvailable: _mergeDiscoveredParts,
          ),
        ] else if (hasModel && _hideModelPreview) ...[
          const Center(child: ProductModelBadge(size: 200)),
        ] else if (hasModel) ...[
          Center(
            child: ProductModelPreview(
              key: ValueKey('${previewProduct.modelPath}|${_modelPart ?? ''}'),
              modelPath: previewProduct.modelPath!,
              size: 200,
              selectedPart: _modelPart,
              knownParts: _availableModelParts,
              onPartsAvailable: _mergeDiscoveredParts,
            ),
          ),
          if (_availableModelParts.length == 1) ...[
            const SizedBox(height: 8),
            const Text(
              'Einzelnes 3D-Objekt erkannt.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
            ),
          ],
        ] else ...[
          Center(
            child: ProductVisualAvatar(product: previewProduct, size: 96),
          ),
        ],
        if (_modelPath != null) ...[
          const SizedBox(height: 8),
          Text(
            '3D-Modell: ${_modelPath!.split(Platform.pathSeparator).last}'
            '${_modelPart != null ? ' · Teil: $_modelPart' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
        if (_imagePath != null) ...[
          const SizedBox(height: 8),
          Text(
            'Bild: ${_imagePath!.split(Platform.pathSeparator).last}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: AdminSecondaryButton(
                label: 'Bild hochladen',
                icon: Icons.upload_file,
                onPressed: _pickImage,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AdminSecondaryButton(
                label: 'Bild entfernen',
                icon: Icons.hide_image_outlined,
                onPressed: _imagePath == null
                    ? null
                    : () => setState(() => _imagePath = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AdminSecondaryButton(
                label: '3D-Modell hochladen',
                icon: Icons.view_in_ar_outlined,
                onPressed: _pickModel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AdminSecondaryButton(
                label: '3D-Modell entfernen',
                icon: Icons.layers_clear_outlined,
                onPressed: _modelPath == null
                    ? null
                    : () async {
                        await _discardStagingModel(_modelPath);
                        if (!mounted) {
                          return;
                        }

                        setState(() {
                          _modelPath = null;
                          _modelPart = null;
                          _availableModelParts = [];
                        });
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Unterstützte 3D-Formate: GLB, GLTF, OBJ (mit MTL/Texturen im gleichen Ordner)',
          style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        const Text(
          'Icon-Fallback (wenn kein Bild/3D)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: productIconOptions.entries.map((entry) {
            final isSelected = _iconKey == entry.key;

            return InkWell(
              onTap: () => setState(() => _iconKey = entry.key),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? AdminColors.accentGradient
                      : AdminColors.cardGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AdminColors.accent
                        : AdminColors.border,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AdminColors.accent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  entry.value,
                  color: isSelected ? Colors.white : AdminColors.textSecondary,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_slotWidth != 1 && _slotWidth != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Slot-Breite wählen.')),
      );
      return;
    }

    setState(() => _formStep += 1);
  }

  Product _buildPreviewProduct() {
    return Product(
      id: widget.product?.id,
      name: _nameController.text.isEmpty ? 'Vorschau' : _nameController.text,
      priceCents: _parseEuroToCents(_priceController.text) ?? 100,
      maxCapacity: int.tryParse(_maxCapacityController.text) ?? 10,
      category: _category,
      slotWidth: _slotWidth,
      imagePath: _imagePath,
      modelPath: _modelPath,
      modelPart: _modelPart,
      iconKey: _iconKey,
    );
  }

  Future<void> _loadModelParts(String path) async {
    final parsed = await ObjModelParser.extractObjectNames(path);

    if (!mounted) {
      return;
    }

    setState(() {
      _availableModelParts = parsed;

      if (_modelPart != null &&
          _modelPart!.isNotEmpty &&
          !_availableModelParts
              .any((part) => part.toLowerCase() == _modelPart!.toLowerCase())) {
        _availableModelParts = ModelPartsHelper.merge(
          _availableModelParts,
          [_modelPart!],
        );
      }

      if (_availableModelParts.isNotEmpty) {
        _modelPart = ObjModelParser.resolvePartName(
          _availableModelParts,
          _modelPart ?? _availableModelParts.first,
        );
      }
    });
  }

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['glb', 'gltf', 'obj'],
      allowMultiple: false,
    );

    final path = result?.files.single.path;

    if (path == null) {
      return;
    }

    setState(() => _isModelUploading = true);

    try {
      await _discardStagingModel(_modelPath);

      final persisted =
          await ProductAssetStorage.ensureModelForPreview(path);

      if (!mounted) {
        return;
      }

      setState(() {
        _modelPath = persisted;
        _modelPart = null;
        _availableModelParts = [];
      });

      await _loadModelParts(persisted);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('3D-Upload fehlgeschlagen: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isModelUploading = false);
      }
    }
  }

  Future<void> _discardStagingModel(String? path) async {
    final originalPath = widget.product?.modelPath;

    if (path == null || path == originalPath) {
      return;
    }

    await ProductAssetStorage.deleteManagedAsset(path);
    LocalFileCache.invalidate(path);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    final path = result?.files.single.path;

    if (path != null) {
      setState(() => _imagePath = path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _formStep = 0);
      return;
    }

    if (_slotWidth != 1 && _slotWidth != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Slot-Breite wählen.')),
      );
      setState(() => _formStep = 0);
      return;
    }

    final maxCapacity = int.parse(_maxCapacityController.text);
    final priceCents = _parseEuroToCents(_priceController.text);

    if (priceCents == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _hideModelPreview = true;
    });

    try {
      final persistedImage =
          await ProductAssetStorage.persistImagePath(_imagePath);
      var persistedModel =
          await ProductAssetStorage.persistModelPath(_modelPath);

      persistedModel = await ProductAssetStorage.finalizeModelSelection(
        modelPath: persistedModel,
        modelPart: _modelPart,
        availableParts: _availableModelParts,
      );

      final previousModelPath = widget.product?.modelPath;
      if (previousModelPath != null &&
          previousModelPath.isNotEmpty &&
          previousModelPath != persistedModel) {
        await ProductAssetStorage.deleteManagedAsset(previousModelPath);
      }

      LocalFileCache.invalidate(persistedImage);
      LocalFileCache.invalidate(persistedModel);

      final product = Product(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        priceCents: priceCents,
        maxCapacity: maxCapacity,
        category: _category,
        slotWidth: _slotWidth,
        imagePath: persistedImage,
        modelPath: persistedModel,
        modelPart: _modelPart,
        iconKey: _iconKey,
      );

      await widget.onSave(product);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $error')),
        );
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  int? _parseEuroToCents(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);

    if (value == null) {
      return null;
    }

    return (value * 100).round();
  }
}
