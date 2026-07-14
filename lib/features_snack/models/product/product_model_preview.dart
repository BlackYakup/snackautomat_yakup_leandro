import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:power3d/power3d.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_widgets.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/local_file_cache.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/obj_model_parser.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/power3d_bootstrap.dart';

/// Einzelner 3D-Viewer – maximal eine Instanz gleichzeitig in der App.
class ProductModelPreview extends StatefulWidget {
  const ProductModelPreview({
    required this.modelPath,
    required this.size,
    this.selectedPart,
    this.knownParts,
    this.onPartsAvailable,
    super.key,
  });

  final String modelPath;
  final double size;
  final String? selectedPart;
  final List<String>? knownParts;
  final ValueChanged<List<String>>? onPartsAvailable;

  @override
  State<ProductModelPreview> createState() => _ProductModelPreviewState();
}

class _ProductModelPreviewState extends State<ProductModelPreview> {
  Power3DController? _controller;
  String? _errorMessage;
  bool _isApplyingPart = false;
  bool _bootstrapped = false;
  bool _blocked = false;
  bool _slotAcquired = false;
  bool _partsLoaded = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Power3dBootstrap.ensureReady();

      if (!mounted) {
        return;
      }

      if (!ProductModelViewerLock.tryAcquire()) {
        setState(() => _blocked = true);
        return;
      }

      _slotAcquired = true;
      _controller = Power3DController()..addListener(_onControllerChanged);

      if (mounted) {
        setState(() => _bootstrapped = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    }
  }

  @override
  void didUpdateWidget(ProductModelPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.modelPath != widget.modelPath) {
      setState(() {
        _errorMessage = null;
        _partsLoaded = false;
      });
    }

    if (oldWidget.selectedPart != widget.selectedPart &&
        _controller?.value.status == Power3DStatus.loaded) {
      _applyPartSelection();
    }
  }

  void _onControllerChanged() {
    if (!mounted || _controller == null) {
      return;
    }

    final status = _controller!.value.status;
    final error = _controller!.value.errorMessage;

    if (status == Power3DStatus.error && error != null) {
      setState(() => _errorMessage = error);
    }
  }

  @override
  void dispose() {
    if (_slotAcquired) {
      ProductModelViewerLock.release();
    }

    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  String get _normalizedPath => p.normalize(widget.modelPath);

  Future<void> _handleModelLoaded() async {
    if (!mounted || _controller == null || _partsLoaded) {
      return;
    }

    _partsLoaded = true;
    setState(() => _errorMessage = null);

    final parts = await _resolveAvailableParts();

    if (!mounted) {
      return;
    }

    if (parts.isNotEmpty) {
      widget.onPartsAvailable?.call(parts);
    }

    await _applyPartSelection(knownParts: parts);
  }

  Future<List<String>> _resolveAvailableParts() async {
    if (_controller == null) {
      return const [];
    }

    final cached = _controller!.value.availableParts;
    if (cached.isNotEmpty) {
      if (widget.knownParts?.isNotEmpty == true) {
        return ModelPartsHelper.merge(widget.knownParts!, cached);
      }
      return cached;
    }

    if (widget.knownParts?.isNotEmpty == true) {
      final webParts = await _controller!.getPartsList();
      return ModelPartsHelper.merge(widget.knownParts!, webParts);
    }

    return _controller!.getPartsList();
  }

  Future<void> _applyPartSelection({List<String>? knownParts}) async {
    if (_isApplyingPart || _controller == null || !mounted) {
      return;
    }

    _isApplyingPart = true;

    try {
      final parts = knownParts ??
          (_controller!.value.availableParts.isNotEmpty
              ? _controller!.value.availableParts
              : await _controller!.getPartsList());
      await _controller!.unhideAll();

      final selected = widget.selectedPart?.trim();

      if (parts.isEmpty || selected == null || selected.isEmpty) {
        return;
      }

      final match = _resolvePartName(parts, selected);

      if (match == null) {
        return;
      }

      await _controller!.selectPart(match);
      await _controller!.hideUnselected();
    } finally {
      _isApplyingPart = false;
    }
  }

  String? _resolvePartName(List<String> parts, String selected) {
    return ObjModelParser.resolvePartName(parts, selected);
  }

  String _shortError(String error) {
    final compact = error.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (compact.length <= 48) {
      return compact;
    }

    return '${compact.substring(0, 45)}...';
  }

  @override
  Widget build(BuildContext context) {
    if (!LocalFileCache.exists(_normalizedPath)) {
      return _ModelFallback(
        size: widget.size,
        missingFile: true,
        message: 'Datei nicht gefunden',
      );
    }

    if (_errorMessage != null) {
      return _ModelFallback(
        size: widget.size,
        missingFile: true,
        message: _shortError(_errorMessage!),
      );
    }

    if (_blocked) {
      return _ModelFallback(
        size: widget.size,
        message: '3D-Vorschau bereits aktiv',
      );
    }

    if (!_bootstrapped || _controller == null) {
      return _ModelFallback(
        size: widget.size,
        message: '3D wird vorbereitet...',
        showSpinner: true,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Power3D.fromFile(
          _normalizedPath,
          key: ValueKey('$_normalizedPath|${widget.selectedPart ?? ''}'),
          controller: _controller,
          lazy: false,
          fileName: p.basename(_normalizedPath),
          onModelLoaded: _handleModelLoaded,
          onMessage: (message) {
            debugPrint('ProductModelPreview: $message');
          },
          loadingUi: (context, controller) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AdminColors.accent,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '3D-Modell wird geladen...',
                    style: TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
          errorWidget: _ModelFallback(
            size: widget.size,
            missingFile: true,
            message: 'Laden fehlgeschlagen',
          ),
        ),
      ),
    );
  }
}

class _ModelFallback extends StatelessWidget {
  const _ModelFallback({
    required this.size,
    this.missingFile = false,
    this.message = '3D',
    this.showSpinner = false,
  });

  final double size;
  final bool missingFile;
  final String message;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8E0FF),
            Color(0xFFD4C4FF),
          ],
        ),
        border: Border.all(color: AdminColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSpinner)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AdminColors.accent,
                ),
              ),
            )
          else
            Icon(
              missingFile ? Icons.broken_image_outlined : Icons.view_in_ar_outlined,
              size: size * 0.3,
              color: AdminColors.accent,
            ),
          if (size >= 80) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size * 0.065,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge für Karten/Slots – kein WebView, nur Hinweis dass ein 3D-Modell existiert.
class ProductModelBadge extends StatelessWidget {
  const ProductModelBadge({
    required this.size,
    super.key,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8E0FF), Color(0xFFD4C4FF)],
        ),
        border: Border.all(color: AdminColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.view_in_ar_outlined,
            size: size * 0.42,
            color: AdminColors.accent,
          ),
          if (size >= 36)
            Text(
              '3D',
              style: TextStyle(
                fontSize: size * 0.18,
                fontWeight: FontWeight.w800,
                color: AdminColors.accent,
              ),
            ),
        ],
      ),
    );
  }
}

/// Vollbild-3D-Vorschau in eigenem Dialog (nur ein Viewer).
Future<void> showProductModelPreviewDialog({
  required BuildContext context,
  required String modelPath,
  String? selectedPart,
  List<String>? knownParts,
}) async {
  final parts = knownParts ??
      (modelPath.toLowerCase().endsWith('.obj')
          ? await ObjModelParser.extractObjectNames(modelPath)
          : const <String>[]);

  if (!context.mounted) {
    return;
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      var activePart = selectedPart ??
          (parts.isNotEmpty ? parts.first : null);

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '3D-Vorschau',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    ProductModelPreview(
                      key: ValueKey('$modelPath|${activePart ?? ''}'),
                      modelPath: modelPath,
                      size: ModelPartsHelper.hasMultipleParts(parts) ? 300 : 420,
                      selectedPart: activePart,
                      knownParts: parts,
                      onPartsAvailable: (discovered) {
                        // Teile werden nur für die Vorschau genutzt.
                      },
                    ),
                    if (ModelPartsHelper.hasMultipleParts(parts)) ...[
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: parts.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final part = parts[index];
                            final isSelected = part == activePart;

                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              title: Text(part, maxLines: 2),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AdminColors.accent,
                                    )
                                  : null,
                              onTap: () {
                                setDialogState(() => activePart = part);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: AdminPrimaryButton(
                        label: 'Schließen',
                        icon: Icons.close,
                        onPressed: () => Navigator.of(dialogContext).pop(),
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
  );
}
