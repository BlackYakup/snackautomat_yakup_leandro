part of 'admin_slots_panel.dart';

class _AssignSlotDialog extends StatefulWidget {
  const _AssignSlotDialog({
    required this.rowLabel,
    required this.columnNumber,
    required this.candidates,
    required this.initialProduct,
    required this.onAssign,
  });

  final String rowLabel;
  final int columnNumber;
  final List<Product> candidates;
  final Product initialProduct;
  final Future<void> Function(Product product, int stock, int priceCents)
      onAssign;

  @override
  State<_AssignSlotDialog> createState() => _AssignSlotDialogState();
}

class _AssignSlotDialogState extends State<_AssignSlotDialog> {
  Product? _selected;
  late final TextEditingController _stockController;
  late final TextEditingController _priceController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialProduct;
    _stockController = TextEditingController(
      text: '${_selected?.maxCapacity ?? 0}',
    );
    _priceController = TextEditingController(
      text: ((_selected?.priceCents ?? 100) / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slotLabel = '${widget.rowLabel}${widget.columnNumber}';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Produkt auf $slotLabel',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Automatenpreis festlegen — Kunden müssen diesen Betrag '
                'einzahlen, bevor das Produkt ausgegeben wird.',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownMenu<Product>(
                initialSelection: _selected,
                label: const Text('Produkt'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: widget.candidates
                    .map(
                      (product) => DropdownMenuEntry(
                        value: product,
                        label:
                            '${product.name} · ${formatCents(product.priceCents)}',
                      ),
                    )
                    .toList(),
                onSelected: (value) {
                  if (value == null) return;
                  setState(() {
                    _selected = value;
                    _stockController.text = '${value.maxCapacity}';
                    _priceController.text =
                        (value.priceCents / 100).toStringAsFixed(2);
                  });
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Automatenpreis (EUR)',
                  helperText: 'z. B. 1,60',
                  prefixText: '€ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: 'Startbestand',
                  helperText: _selected == null
                      ? null
                      : 'Max. ${_selected!.maxCapacity}',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AdminSecondaryButton(
                      label: 'Abbrechen',
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminPrimaryButton(
                      label: 'Zuweisen',
                      icon: Icons.check,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final product = _selected;
    if (product == null) return;

    final priceCents = _parseEuroToCents(_priceController.text);
    if (priceCents == null || priceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte einen gültigen Preis größer 0 eingeben.'),
        ),
      );
      return;
    }

    final stock = int.tryParse(_stockController.text) ?? 0;
    if (stock < 0 || stock > product.maxCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bestand muss zwischen 0 und ${product.maxCapacity} liegen.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    await widget.onAssign(product, stock, priceCents);
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

class _OccupiedSlotDialog extends StatefulWidget {
  const _OccupiedSlotDialog({
    required this.placed,
    required this.onClear,
    required this.onRefill,
    required this.onSavePrice,
  });

  final PlacedProduct placed;
  final Future<void> Function() onClear;
  final Future<void> Function() onRefill;
  final Future<void> Function(int priceCents) onSavePrice;

  @override
  State<_OccupiedSlotDialog> createState() => _OccupiedSlotDialogState();
}

class _OccupiedSlotDialogState extends State<_OccupiedSlotDialog> {
  late final TextEditingController _priceController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: (widget.placed.priceCents / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placed = widget.placed;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProductVisualAvatar(product: placed.product, size: 64),
              const SizedBox(height: 12),
              Text(
                placed.name,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Slot ${placed.slotCode} · Bestand ${placed.stockQuantity}/${placed.maxCapacity}',
                style: const TextStyle(color: AdminColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Automatenpreis (EUR)',
                  prefixText: '€ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AdminPrimaryButton(
                  label: 'Preis speichern',
                  icon: Icons.euro,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _savePrice,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: AdminPrimaryButton(
                  label: 'Auffüllen',
                  icon: Icons.add_box_outlined,
                  onPressed: widget.onRefill,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: AdminSecondaryButton(
                  label: 'Slot freigeben',
                  icon: Icons.clear_all,
                  onPressed: widget.onClear,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Schließen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePrice() async {
    final priceCents = _parseEuroToCents(_priceController.text);
    if (priceCents == null || priceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte einen gültigen Preis größer 0 eingeben.'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    await widget.onSavePrice(priceCents);
    if (mounted) setState(() => _isSaving = false);
  }
}

class _SlotRefillDialog extends StatefulWidget {
  const _SlotRefillDialog({
    required this.placed,
    required this.onRefill,
    required this.onRefillToMax,
    required this.onSetStock,
  });

  final PlacedProduct placed;
  final Future<void> Function(int amount) onRefill;
  final Future<void> Function() onRefillToMax;
  final Future<void> Function(int stock) onSetStock;

  @override
  State<_SlotRefillDialog> createState() => _SlotRefillDialogState();
}

class _SlotRefillDialogState extends State<_SlotRefillDialog> {
  late int _stock;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _stock = widget.placed.stockQuantity;
  }

  @override
  Widget build(BuildContext context) {
    final placed = widget.placed;
    final missing = placed.maxCapacity - _stock;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProductVisualAvatar(product: placed.product, size: 64),
              const SizedBox(height: 12),
              Text(
                placed.name,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Position ${placed.slotCode} · ${formatCents(placed.priceCents)}',
                style: const TextStyle(color: AdminColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                '$_stock von ${placed.maxCapacity}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                missing > 0
                    ? 'Noch $missing Stück bis voll'
                    : 'Slot ist voll befüllt',
                style: const TextStyle(color: AdminColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  AdminChipButton(
                    label: '+1',
                    selected: true,
                    onPressed: _isSaving || _stock >= placed.maxCapacity
                        ? null
                        : () => _applyRefill(1),
                  ),
                  AdminChipButton(
                    label: '+5',
                    selected: true,
                    onPressed: _isSaving || _stock >= placed.maxCapacity
                        ? null
                        : () => _applyRefill(5),
                  ),
                  AdminChipButton(
                    label: 'Voll auffüllen',
                    selected: true,
                    onPressed: _isSaving || _stock >= placed.maxCapacity
                        ? null
                        : _applyRefillToMax,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AdminSecondaryButton(
                      label: 'Abbrechen',
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminPrimaryButton(
                      label: 'Speichern',
                      icon: Icons.check,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _saveStock,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyRefill(int amount) async {
    setState(() => _isSaving = true);
    await widget.onRefill(amount);
    if (!mounted) return;
    setState(() {
      _stock = (_stock + amount).clamp(0, widget.placed.maxCapacity);
      _isSaving = false;
    });
  }

  Future<void> _applyRefillToMax() async {
    setState(() => _isSaving = true);
    await widget.onRefillToMax();
    if (!mounted) return;
    setState(() {
      _stock = widget.placed.maxCapacity;
      _isSaving = false;
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveStock() async {
    setState(() => _isSaving = true);
    await widget.onSetStock(_stock);
    if (mounted) Navigator.of(context).pop();
  }
}

int? _parseEuroToCents(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  final value = double.tryParse(normalized);
  if (value == null) return null;
  return (value * 100).round();
}
