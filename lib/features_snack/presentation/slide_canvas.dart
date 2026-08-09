part of 'slide_editor_library.dart';

/// Feste Folien-Leinwand: Abspielen und Bearbeiten nutzen dieselbe Geometrie.
class SlideCanvas extends StatefulWidget {
  const SlideCanvas({
    super.key,
    required this.editing,
    required this.elements,
    required this.onChange,
    this.controller,
  });

  final bool editing;
  final List<OverlayEl> elements;
  final ValueChanged<List<OverlayEl>> onChange;
  final SlideCanvasController? controller;

  @override
  State<SlideCanvas> createState() => SlideCanvasState();
}

class SlideCanvasState extends State<SlideCanvas> {
  final LinkedHashSet<String> _selectedIds = LinkedHashSet();
  List<OverlayEl> _clipboardEls = const [];
  final _focus = FocusNode();
  bool _draggingFiles = false;
  List<_GuideLine> _guides = const [];

  /// Ursprungspositionen beim Gruppen-Ziehen.
  Map<String, Offset>? _dragOrigins;

  /// Rahmen-Auswahl (Prozent 0–100).
  Offset? _marqueeStart;
  Offset? _marqueeEnd;

  final List<List<OverlayEl>> _undoStack = [];
  final List<List<OverlayEl>> _redoStack = [];
  bool _historyLock = false;

  /// Ephemere Play-Overrides (HUD/Detail), nicht persistiert.
  final Map<String, String> _playTextOverrides = {};

  static const _snapThreshold = 0.85;
  static const _clipPrefix = 'SNACK_OVERLAY_V1:';

  OverlayEl _viewEl(OverlayEl el) {
    final override = _playTextOverrides[el.id];
    if (override == null) return el;
    return el.copy()..text = override;
  }

  void _onPlayTap(OverlayEl el) {
    if (widget.editing) return;
    final step = RegExp(r'_step(\d+)$').firstMatch(el.id);
    if (step != null) {
      _applyFlowPhase(int.parse(step.group(1)!));
      return;
    }
    if (!RegExp(r'_tr\d+$').hasMatch(el.id)) return;
    final label = (el.text ?? '').toLowerCase();
    if (label.contains('slot')) {
      _applyFlowPhase(0);
    } else if (label.contains('münz') || label.contains('munz')) {
      _applyFlowPhase(1);
    } else if (label.contains('ausgabe') || label.contains('klappe')) {
      _applyFlowPhase(2);
    } else if (label.contains('zurück') ||
        label.contains('zuruck') ||
        label.contains('reset')) {
      _applyFlowPhase(0);
    }
  }

  void _applyFlowPhase(int phase) {
    String? hudId;
    String? detailId;
    for (final e in widget.elements) {
      if (e.module == 'hud' || e.id.endsWith('_hud')) hudId = e.id;
      if (e.id.endsWith('_detail')) detailId = e.id;
    }
    if (hudId == null && detailId == null) return;

    final data = switch (phase) {
      1 => (
          hud:
              'HUD / OLED  ·  ZAHLUNG\n\nZAHLUNG\nBitte bezahlen…\n\nMünzen/Karte: inserted steigt',
          detail:
              'Münzen/Karte: inserted steigt, missing sinkt. UI und Session sperren Slot-Wechsel.',
          label: 'ZAHLUNG',
        ),
      2 => (
          hud:
              'HUD / OLED  ·  AUSGABE\n\nAUSGABE…\nBitte warten\n\nHandler: dispenseItem(slot)',
          detail:
              'Handler: dispenseItem(slot) → Aufzug/Spirale, danach setDeliveryFlapOpen.',
          label: 'AUSGABE',
        ),
      3 => (
          hud:
              'HUD / OLED  ·  DANKE\n\nVIELEN DANK\nGuten Appetit\n\nKurzanzeige, dann Reset',
          detail: 'Kurzanzeige, dann Reset auf BEREIT. Stock wurde bereits −1.',
          label: 'DANKE',
        ),
      _ => (
          hud:
              'HUD / OLED  ·  BEREIT\n\nWÄHLE DEIN PRODUKT\nCode eingeben  ·  z. B. A1\n\nMünzen einwerfen · Preis bezahlen',
          detail:
              'Slot tippen (Sidebar/Keypad) setzt selectedSlotCode. Display zeigt Idle.',
          label: 'BEREIT',
        ),
    };

    setState(() {
      if (hudId != null) _playTextOverrides[hudId] = data.hud;
      if (detailId != null) _playTextOverrides[detailId] = data.detail;
    });
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void _emit(List<OverlayEl> next, {bool record = true}) {
    if (record && !_historyLock) {
      _undoStack.add(widget.elements.map((e) => e.copy()).toList());
      if (_undoStack.length > 60) _undoStack.removeAt(0);
      _redoStack.clear();
    }
    widget.onChange(next);
    widget.controller?.ping();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _historyLock = true;
    _redoStack.add(widget.elements.map((e) => e.copy()).toList());
    final prev = _undoStack.removeLast();
    widget.onChange(prev);
    _historyLock = false;
    setState(() {});
    widget.controller?.ping();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _historyLock = true;
    _undoStack.add(widget.elements.map((e) => e.copy()).toList());
    final next = _redoStack.removeLast();
    widget.onChange(next);
    _historyLock = false;
    setState(() {});
    widget.controller?.ping();
  }

  Future<void> copySelection() async {
    final ids = _selectedIds.isEmpty
        ? <String>{}
        : Set<String>.from(_selectedIds);
    if (ids.isEmpty) return;
    final els = widget.elements
        .where((e) => ids.contains(e.id))
        .map((e) => e.copy())
        .toList();
    if (els.isEmpty) return;
    _clipboardEls = els;
    final payload = {
      'v': 1,
      'els': els.map((e) => e.toJson()).toList(),
    };
    await Clipboard.setData(
      ClipboardData(text: '$_clipPrefix${jsonEncode(payload)}'),
    );
  }

  Future<void> pasteClipboard() async {
    // 1) Interne Overlay-Zwischenablage / JSON
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.startsWith(_clipPrefix)) {
      try {
        final raw = jsonDecode(text.substring(_clipPrefix.length));
        if (raw is Map && raw['els'] is List) {
          final pasted = <OverlayEl>[];
          for (final item in raw['els'] as List) {
            if (item is! Map) continue;
            final el = OverlayEl.fromJson(Map<String, dynamic>.from(item))
                .cloneWithNewId();
            pasted.add(el);
          }
          if (pasted.isNotEmpty) {
            addElements(pasted);
            return;
          }
        }
      } catch (_) {/* fall through */}
    }

    if (_clipboardEls.isNotEmpty) {
      addElements(_clipboardEls.map((e) => e.cloneWithNewId()).toList());
      return;
    }

    // 2) Externer Text
    if (text != null && text.trim().isNotEmpty && !text.startsWith(_clipPrefix)) {
      final t = text.trim();
      final lower = t.toLowerCase();
      if (lower.endsWith('.mp4') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.mkv')) {
        _add(_createVideoPlaceholder(t));
        return;
      }
      if ((lower.endsWith('.png') ||
              lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.webp') ||
              lower.endsWith('.gif')) &&
          (t.contains('\\') || t.contains('/'))) {
        _add(createImageOverlay(t));
        return;
      }
      final el = createTextOverlay();
      el.text = t;
      // grobe Breite an Textlänge
      el.w = (12.0 + t.length * 0.55).clamp(12, 70);
      el.h = t.contains('\n') ? 12 : 5;
      _add(el);
      return;
    }

    // 3) Bild aus System-Zwischenablage
    try {
      final bytes = await Pasteboard.image;
      if (bytes != null && bytes.isNotEmpty) {
        final path = await _persistClipboardImage(bytes);
        if (path != null) {
          _add(createImageOverlay(path));
          return;
        }
      }
    } catch (_) {/* ignore */}

    // 4) Dateipfade aus Pasteboard (Bild/Video)
    try {
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        for (final path in files) {
          final lower = path.toLowerCase();
          if (lower.endsWith('.png') ||
              lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.webp') ||
              lower.endsWith('.gif') ||
              lower.endsWith('.bmp')) {
            _add(createImageOverlay(path));
          } else if (lower.endsWith('.mp4') ||
              lower.endsWith('.webm') ||
              lower.endsWith('.mov') ||
              lower.endsWith('.mkv')) {
            _add(_createVideoPlaceholder(path));
          }
        }
      }
    } catch (_) {/* ignore */}
  }

  OverlayEl _createVideoPlaceholder(String path) {
    final name = p.basename(path);
    return OverlayEl(
      id: overlayUid('vid'),
      kind: OverlayKind.box,
      x: 30,
      y: 30,
      w: 36,
      h: 18,
      text: '🎬  $name\n$path',
      fontSize: 13,
      color: '#E8EEF2',
      bg: '#151A1F',
      src: path,
      radius: 12,
      pad: 12,
      module: 'video',
    );
  }

  Future<String?> _persistClipboardImage(Uint8List bytes) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final folder = Directory(p.join(dir.path, 'presentation_paste'));
      if (!await folder.exists()) await folder.create(recursive: true);
      final file = File(
        p.join(folder.path, 'paste_${DateTime.now().millisecondsSinceEpoch}.png'),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  bool _isSelected(String id) => _selectedIds.contains(id);

  OverlayEl? get selectedEl {
    final id = _selectedIds.isEmpty ? null : _selectedIds.last;
    if (id == null) return null;
    for (final e in widget.elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  void _syncSelection(String? id, {bool notify = true}) {
    _selectedIds
      ..clear()
      ..addAll([?id]);
    widget.controller?.select(id, notify: notify);
  }

  void _syncSelectionMany(Iterable<String> ids, {bool notify = true}) {
    _selectedIds
      ..clear()
      ..addAll(ids);
    widget.controller?.selectMany(ids, notify: notify);
  }

  void _toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    widget.controller?.selectMany(_selectedIds);
  }

  void updateSelected(void Function(OverlayEl el) patch) {
    final sel = selectedEl;
    if (sel == null) return;
    _update(sel.id, patch);
  }

  void selectAll() {
    setState(() => _syncSelectionMany(widget.elements.map((e) => e.id)));
  }

  void removeSelected() {
    if (_selectedIds.isEmpty) return;
    final remove = Set<String>.from(_selectedIds);
    _emit(
      widget.elements.where((e) => !remove.contains(e.id)).toList(),
    );
    setState(() => _syncSelection(null));
  }

  void bringSelectedForward() {
    if (_selectedIds.isEmpty) return;
    final maxZ = widget.elements.fold<int>(0, (m, e) => math.max(m, e.z));
    var z = maxZ;
    final next = widget.elements.map((e) {
      if (!_selectedIds.contains(e.id)) return e;
      final c = e.copy();
      c.z = ++z;
      return c;
    }).toList();
    _emit(next);
  }

  void addText() => _add(createTextOverlay());
  void addBox() => _add(createBoxOverlay());
  void addElements(List<OverlayEl> els) {
    if (els.isEmpty) return;
    _emit([...widget.elements, ...els]);
    setState(() => _syncSelectionMany(els.map((e) => e.id)));
  }

  void addHintModule() => _add(createHintModule());
  void addSectionModule() => _add(createSectionModule());
  void addTitleBodyModule() => addElements(createTitleBodyModule());
  void addStepModule() {
    final nums = widget.elements
        .where((e) =>
            e.kind == OverlayKind.box &&
            e.bg == '#1F8F84' &&
            (int.tryParse(e.text?.trim() ?? '') != null))
        .map((e) => int.parse(e.text!.trim()))
        .toList();
    final next = nums.isEmpty ? 1 : (nums.reduce(math.max) + 1).clamp(1, 99);
    addElements(createStepModule(number: next));
  }

  Future<void> pickImage() => _pickImage();

  void _update(String id, void Function(OverlayEl el) patch) {
    final next = widget.elements.map((e) {
      if (e.id != id) return e;
      final c = e.copy();
      patch(c);
      return c;
    }).toList();
    _emit(next);
  }

  void _updateMany(void Function(OverlayEl el) patch, Set<String> ids) {
    final next = widget.elements.map((e) {
      if (!ids.contains(e.id)) return e;
      final c = e.copy();
      patch(c);
      return c;
    }).toList();
    _emit(next);
  }

  void _add(OverlayEl el) {
    _emit([...widget.elements, el]);
    setState(() => _syncSelection(el.id));
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return;
    _add(createImageOverlay(path));
  }

  void _addDroppedImages(List<String> paths) {
    for (final path in paths) {
      final lower = path.toLowerCase();
      if (!(lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.bmp'))) {
        continue;
      }
      _add(createImageOverlay(path));
    }
  }

  void _clearGuides() {
    _dragOrigins = null;
    if (_guides.isEmpty) return;
    setState(() => _guides = const []);
  }

  void _moveWithSnap(String id, double x, double y) {
    // Mehrfachauswahl: alle zusammen verschieben
    if (_selectedIds.length > 1 && _selectedIds.contains(id)) {
      _moveGroup(id, x, y);
      return;
    }

    OverlayEl? moving;
    for (final e in widget.elements) {
      if (e.id == id) {
        moving = e;
        break;
      }
    }
    if (moving == null) return;
    final others = widget.elements.where((e) => e.id != id).toList();
    final snapped = _CanvasSnap.snapMove(
      x: x,
      y: y,
      w: moving.w,
      h: moving.h,
      others: others,
      threshold: _snapThreshold,
    );
    setState(() => _guides = snapped.guides);
    _update(id, (e) {
      e.x = snapped.x.clamp(0, math.max(0, 100 - e.w));
      e.y = snapped.y.clamp(0, math.max(0, 100 - e.h));
    });
  }

  void _moveGroup(String leaderId, double x, double y) {
    if (_dragOrigins == null || !_dragOrigins!.containsKey(leaderId)) {
      _prepareGroupDrag(leaderId);
    }
    final origin = _dragOrigins![leaderId];
    if (origin == null) return;
    final dx = x - origin.dx;
    final dy = y - origin.dy;
    final next = widget.elements.map((e) {
      final base = _dragOrigins![e.id];
      if (base == null) return e;
      final c = e.copy();
      c.x = (base.dx + dx).clamp(0.0, math.max(0.0, 100 - c.w));
      c.y = (base.dy + dy).clamp(0.0, math.max(0.0, 100 - c.h));
      return c;
    }).toList();
    setState(() => _guides = const []);
    _emit(next);
  }

  void _resizeWithSnap(String id, double nw, double nh) {
    OverlayEl? moving;
    for (final e in widget.elements) {
      if (e.id == id) {
        moving = e;
        break;
      }
    }
    if (moving == null) return;
    final others = widget.elements.where((e) => e.id != id).toList();
    final snapped = _CanvasSnap.snapResize(
      x: moving.x,
      y: moving.y,
      w: nw,
      h: nh,
      others: others,
      threshold: _snapThreshold,
    );
    setState(() => _guides = snapped.guides);
    _update(id, (e) {
      e.w = snapped.w.clamp(4, math.max(4, 100 - e.x));
      e.h = snapped.h.clamp(4, math.max(4, 100 - e.y));
    });
  }

  void _onSelectTap(String id) {
    setState(() {
      if (_isModifierPressed()) {
        _toggleSelection(id);
      } else if (!_selectedIds.contains(id)) {
        _syncSelection(id);
      }
      // Bereits in Mehrfachauswahl: Auswahl behalten (Gruppenzug)
    });
    _focus.requestFocus();
  }

  /// Vor dem Ziehen: Ursprünge aller ausgewählten Elemente merken.
  void _prepareGroupDrag(String id) {
    if (!_selectedIds.contains(id)) {
      _syncSelection(id);
    }
    _dragOrigins = {
      for (final e in widget.elements)
        if (_selectedIds.contains(e.id)) e.id: Offset(e.x, e.y),
    };
  }

  void _finishMarquee() {
    final start = _marqueeStart;
    final end = _marqueeEnd;
    if (start == null || end == null) {
      _marqueeStart = null;
      _marqueeEnd = null;
      return;
    }
    final rect = Rect.fromPoints(start, end);
    // Zu kleiner Klick → nur Auswahl leeren (außer Strg)
    if (rect.width.abs() < 0.5 && rect.height.abs() < 0.5) {
      setState(() {
        _marqueeStart = null;
        _marqueeEnd = null;
        if (!_isModifierPressed()) _syncSelection(null);
      });
      return;
    }
    final hit = <String>[];
    for (final e in widget.elements) {
      final er = Rect.fromLTWH(e.x, e.y, e.w, e.h);
      if (rect.overlaps(er)) hit.add(e.id);
    }
    setState(() {
      _marqueeStart = null;
      _marqueeEnd = null;
      if (_isModifierPressed()) {
        _syncSelectionMany({..._selectedIds, ...hit});
      } else {
        _syncSelectionMany(hit);
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.editing || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final isCtrl = _isModifierPressed();

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyA) {
      setState(() => _syncSelectionMany(widget.elements.map((e) => e.id)));
      return KeyEventResult.handled;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        redo();
      } else {
        undo();
      }
      return KeyEventResult.handled;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
      redo();
      return KeyEventResult.handled;
    }
    if (isCtrl &&
        event.logicalKey == LogicalKeyboardKey.keyC &&
        _selectedIds.isNotEmpty) {
      unawaited(copySelection());
      return KeyEventResult.handled;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyV) {
      unawaited(pasteClipboard());
      return KeyEventResult.handled;
    }
    if ((event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace) &&
        _selectedIds.isNotEmpty) {
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx != null &&
          (ctx.widget is EditableText ||
              ctx.findAncestorWidgetOfExactType<EditableText>() != null ||
              ctx.findAncestorWidgetOfExactType<TextField>() != null ||
              ctx.findAncestorWidgetOfExactType<TextFormField>() != null)) {
        return KeyEventResult.ignored;
      }
      removeSelected();
      return KeyEventResult.handled;
    }

    if (_selectedIds.isNotEmpty) {
      const step = 0.4;
      double? dx;
      double? dy;
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) dx = -step;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) dx = step;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) dy = -step;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) dy = step;
      if (dx != null || dy != null) {
        final ddx = dx ?? 0;
        final ddy = dy ?? 0;
        _updateMany((e) {
          e.x = (e.x + ddx).clamp(0, math.max(0, 100 - e.w));
          e.y = (e.y + ddy).clamp(0, math.max(0, 100 - e.h));
        }, _selectedIds);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant SlideCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing && oldWidget.editing) {
      setState(() => _syncSelection(null, notify: false));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller?.select(null);
      });
    }
    if (widget.editing && !oldWidget.editing) {
      _playTextOverrides.clear();
    }
    final oldIds = oldWidget.elements.map((e) => e.id).toSet();
    final newIds = widget.elements.map((e) => e.id).toSet();
    if (oldIds.isNotEmpty &&
        newIds.isNotEmpty &&
        oldIds.intersection(newIds).isEmpty) {
      _undoStack.clear();
      _redoStack.clear();
      _playTextOverrides.clear();
    }
    final pruned = _selectedIds.where(newIds.contains).toList();
    if (pruned.length != _selectedIds.length) {
      _syncSelectionMany(pruned, notify: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller?.selectMany(pruned);
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.elements]..sort((a, b) => a.z.compareTo(b.z));

    return Focus(
      focusNode: _focus,
      autofocus: widget.editing,
      onKeyEvent: _onKey,
      child: DropTarget(
        enable: widget.editing,
        onDragEntered: (_) => setState(() => _draggingFiles = true),
        onDragExited: (_) => setState(() => _draggingFiles = false),
        onDragDone: (detail) {
          setState(() => _draggingFiles = false);
          _addDroppedImages(detail.files.map((f) => f.path).toList());
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                if (widget.editing)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() => _syncSelection(null));
                        _focus.requestFocus();
                      },
                      onPanStart: (d) {
                        final pct = Offset(
                          d.localPosition.dx / w * 100,
                          d.localPosition.dy / h * 100,
                        );
                        setState(() {
                          _marqueeStart = pct;
                          _marqueeEnd = pct;
                        });
                      },
                      onPanUpdate: (d) {
                        if (_marqueeStart == null) return;
                        setState(() {
                          _marqueeEnd = Offset(
                            d.localPosition.dx / w * 100,
                            d.localPosition.dy / h * 100,
                          );
                        });
                      },
                      onPanEnd: (_) {
                        _finishMarquee();
                        _focus.requestFocus();
                      },
                      onPanCancel: () {
                        setState(() {
                          _marqueeStart = null;
                          _marqueeEnd = null;
                        });
                      },
                      child: ColoredBox(
                        color: _draggingFiles
                            ? const Color(0xFF1F8F84).withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                for (final el in sorted)
                  Positioned(
                    left: el.x / 100 * w,
                    top: el.y / 100 * h,
                    width: el.w / 100 * w,
                    height: el.h / 100 * h,
                    child: _CanvasItem(
                      key: ValueKey(el.id),
                      el: _viewEl(el),
                      selected: widget.editing && _isSelected(el.id),
                      primary: widget.editing &&
                          _selectedIds.isNotEmpty &&
                          _selectedIds.last == el.id,
                      editing: widget.editing,
                      parentSize: Size(w, h),
                      onSelect: () {
                        if (!widget.editing) return;
                        _onSelectTap(el.id);
                      },
                      onPlayTap: () => _onPlayTap(el),
                      onMoveStart: () {
                        if (!widget.editing) return;
                        _prepareGroupDrag(el.id);
                      },
                      onMoveTo: (x, y) => _moveWithSnap(el.id, x, y),
                      onResizeTo: (nw, nh) => _resizeWithSnap(el.id, nw, nh),
                      onGestureEnd: _clearGuides,
                      onTextCommit: (v) =>
                          _update(el.id, (e) => e.text = v),
                    ),
                  ),
                if (widget.editing &&
                    _marqueeStart != null &&
                    _marqueeEnd != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MarqueePainter(
                          rect: Rect.fromPoints(_marqueeStart!, _marqueeEnd!),
                        ),
                      ),
                    ),
                  ),
                if (widget.editing && _guides.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GuidePainter(guides: _guides),
                      ),
                    ),
                  ),
                if (widget.editing && _draggingFiles)
                  const IgnorePointer(
                    child: Center(child: _DropHint()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DropHint extends StatelessWidget {
  const _DropHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xF2141A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PresentationTheme.accent.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'Bild hier ablegen',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
