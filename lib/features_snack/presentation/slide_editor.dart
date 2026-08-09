import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/overlay_models.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/slide_widgets.dart';

/// Controller für Auswahl / Studio-Dock (außerhalb der Leinwand).
class SlideCanvasController extends ChangeNotifier {
  final LinkedHashSet<String> selectedIds = LinkedHashSet();

  /// Primäre Auswahl (zuletzt gewählt) für das Studio-Panel.
  String? get selectedId =>
      selectedIds.isEmpty ? null : selectedIds.last;

  void select(String? id, {bool notify = true}) {
    final next = <String>{if (id != null) id};
    if (setEquals(selectedIds, next)) return;
    selectedIds
      ..clear()
      ..addAll(next);
    if (notify) notifyListeners();
  }

  void selectMany(Iterable<String> ids, {bool notify = true}) {
    final next = LinkedHashSet<String>.from(ids);
    if (setEquals(selectedIds, next)) return;
    selectedIds
      ..clear()
      ..addAll(next);
    if (notify) notifyListeners();
  }

  void toggle(String id, {bool notify = true}) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    if (notify) notifyListeners();
  }

  void ping() => notifyListeners();
}

bool setEquals(Set<String> a, Set<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final e in a) {
    if (!b.contains(e)) return false;
  }
  return true;
}

bool _isModifierPressed() {
  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  return keys.contains(LogicalKeyboardKey.controlLeft) ||
      keys.contains(LogicalKeyboardKey.controlRight) ||
      keys.contains(LogicalKeyboardKey.metaLeft) ||
      keys.contains(LogicalKeyboardKey.metaRight) ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;
}

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
      ..addAll([if (id != null) id]);
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

class PresentationEditorDock extends StatelessWidget {
  const PresentationEditorDock({
    super.key,
    required this.selected,
    required this.onAddText,
    required this.onAddBox,
    required this.onAddHint,
    required this.onAddStep,
    required this.onAddSection,
    required this.onAddTitleBody,
    required this.onPickImage,
    required this.onReset,
    required this.onDelete,
    required this.onBringForward,
    required this.onPatch,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
  });

  final OverlayEl? selected;
  final VoidCallback onAddText;
  final VoidCallback onAddBox;
  final VoidCallback onAddHint;
  final VoidCallback onAddStep;
  final VoidCallback onAddSection;
  final VoidCallback onAddTitleBody;
  final VoidCallback onPickImage;
  final VoidCallback? onReset;
  final VoidCallback? onDelete;
  final VoidCallback? onBringForward;
  final void Function(void Function(OverlayEl)) onPatch;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  static const _bg = Color(0xFF12171C);
  static const _card = Color(0xFF1B2229);
  static const _line = Color(0xFF2A333C);

  @override
  Widget build(BuildContext context) {
    final sel = selected;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(-6, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: PresentationTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Strg+Z/Y · Strg+C/V · Ecke = skalieren',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: _ToolTile(
                      icon: Icons.undo_rounded,
                      label: 'Zurück',
                      onTap: canUndo ? onUndo : null,
                      muted: !canUndo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ToolTile(
                      icon: Icons.redo_rounded,
                      label: 'Vor',
                      onTap: canRedo ? onRedo : null,
                      muted: !canRedo,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.65,
                    children: [
                      _ToolTile(
                        icon: Icons.title_rounded,
                        label: 'Text',
                        onTap: onAddText,
                      ),
                      _ToolTile(
                        icon: Icons.crop_square_rounded,
                        label: 'Kasten',
                        onTap: onAddBox,
                      ),
                      _ToolTile(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Hinweis',
                        onTap: onAddHint,
                      ),
                      _ToolTile(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Schritt',
                        onTap: onAddStep,
                      ),
                      _ToolTile(
                        icon: Icons.label_outline_rounded,
                        label: 'Abschnitt',
                        onTap: onAddSection,
                      ),
                      _ToolTile(
                        icon: Icons.short_text_rounded,
                        label: 'Titel+Text',
                        onTap: onAddTitleBody,
                      ),
                      _ToolTile(
                        icon: Icons.add_photo_alternate_outlined,
                        label: 'Bild',
                        onTap: onPickImage,
                      ),
                      _ToolTile(
                        icon: Icons.restart_alt_rounded,
                        label: 'Reset',
                        onTap: onReset,
                        muted: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (sel == null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: Text(
                        'Element anklicken.\n'
                        'Strg+Klick = Mehrfachauswahl\n'
                        'Leerfläche ziehen = Rahmen\n'
                        'Ecke = skalieren\n'
                        'Strg+Z = zurück',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // reuse existing selected panel content by keeping below
                          _SelectedInspector(
                            selected: sel,
                            onDelete: onDelete,
                            onBringForward: onBringForward,
                            onPatch: onPatch,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedInspector extends StatelessWidget {
  const _SelectedInspector({
    required this.selected,
    required this.onDelete,
    required this.onBringForward,
    required this.onPatch,
  });

  final OverlayEl selected;
  final VoidCallback? onDelete;
  final VoidCallback? onBringForward;
  final void Function(void Function(OverlayEl)) onPatch;

  static const _bg = Color(0xFF12171C);
  static const _line = Color(0xFF2A333C);

  @override
  Widget build(BuildContext context) {
    final sel = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _kindLabel(sel),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MiniAction(
                icon: Icons.flip_to_front_rounded,
                label: 'Vorne',
                onTap: onBringForward,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniAction(
                icon: Icons.delete_outline_rounded,
                label: 'Löschen',
                danger: true,
                onTap: onDelete,
              ),
            ),
          ],
        ),
        if (sel.kind == OverlayKind.text || sel.kind == OverlayKind.box) ...[
          const SizedBox(height: 14),
          _fieldLabel('Inhalt'),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('txt_${sel.id}'),
            initialValue: sel.text ?? '',
            maxLines: 5,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDeco(),
            onChanged: (v) => onPatch((e) => e.text = v),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Schrift ${(sel.fontSize ?? 16).round()}'),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: PresentationTheme.accent,
              thumbColor: Colors.white,
              inactiveTrackColor: _line,
            ),
            child: Slider(
              value: (sel.fontSize ?? 16).clamp(8, 72),
              min: 8,
              max: 72,
              onChanged: (v) => onPatch((e) => e.fontSize = v),
            ),
          ),
          _fieldLabel('Ausrichtung'),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) return Colors.white;
                return Colors.white54;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) {
                  return PresentationTheme.accent;
                }
                return _bg;
              }),
            ),
            segments: const [
              ButtonSegment(
                value: 'left',
                icon: Icon(Icons.format_align_left, size: 16),
              ),
              ButtonSegment(
                value: 'center',
                icon: Icon(Icons.format_align_center, size: 16),
              ),
              ButtonSegment(
                value: 'right',
                icon: Icon(Icons.format_align_right, size: 16),
              ),
            ],
            selected: {
              sel.align == 'center'
                  ? 'center'
                  : (sel.align == 'right' ? 'right' : 'left'),
            },
            onSelectionChanged: (s) => onPatch((e) => e.align = s.first),
          ),
        ],
        if (sel.kind == OverlayKind.image) ...[
          const SizedBox(height: 14),
          _fieldLabel('Einpassung'),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) return Colors.white;
                return Colors.white54;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) {
                  return PresentationTheme.accent;
                }
                return _bg;
              }),
            ),
            segments: const [
              ButtonSegment(value: 'cover', label: Text('Füllen')),
              ButtonSegment(value: 'contain', label: Text('Einpassen')),
            ],
            selected: {sel.fit == 'contain' ? 'contain' : 'cover'},
            onSelectionChanged: (s) => onPatch((e) => e.fit = s.first),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Zuschneiden'),
          _cropSlider(context, 'Links', sel.cropL, (v) => onPatch((e) => e.cropL = v)),
          _cropSlider(context, 'Rechts', sel.cropR, (v) => onPatch((e) => e.cropR = v)),
          _cropSlider(context, 'Oben', sel.cropT, (v) => onPatch((e) => e.cropT = v)),
          _cropSlider(context, 'Unten', sel.cropB, (v) => onPatch((e) => e.cropB = v)),
          TextButton(
            onPressed: () => onPatch((e) {
              e.cropL = 0;
              e.cropR = 0;
              e.cropT = 0;
              e.cropB = 0;
            }),
            child: Text(
              'Zuschnitt zurücksetzen',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ],
    );
  }

  static String _kindLabel(OverlayEl el) {
    final mod = el.module;
    if (mod == 'hud' || mod == 'hud_panel') return 'HUD / Display';
    if (mod == 'hint') return 'Hinweis';
    if (mod == 'step_num' || mod == 'step_body') return 'Schritt';
    if (mod == 'section_folder' || mod == 'section_book') return 'Abschnitt';
    if (mod == 'code_panel' || mod == 'code_head' || mod == 'code_body') {
      return 'Code-Panel';
    }
    return switch (el.kind) {
      OverlayKind.text => 'Text-Element',
      OverlayKind.box => 'Kasten',
      OverlayKind.image => 'Bild',
    };
  }

  static Widget _fieldLabel(String t) => Text(
        t,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );

  static InputDecoration _inputDeco() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: PresentationTheme.accent),
        ),
      );

  Widget _cropSlider(
    BuildContext context,
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label ${(value * 100).round()}%',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: PresentationTheme.accent,
            thumbColor: Colors.white,
            inactiveTrackColor: _line,
          ),
          child: Slider(
            value: value.clamp(0, 0.45),
            min: 0,
            max: 0.45,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}


class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: muted ? const Color(0xFF171D23) : const Color(0xFF1B2229),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A333C)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: muted
                    ? Colors.white38
                    : PresentationTheme.accent.withValues(alpha: 0.95),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: muted ? 0.45 : 0.85),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B6B) : Colors.white70;
    return Material(
      color: const Color(0xFF12171C),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasItem extends StatefulWidget {
  const _CanvasItem({
    super.key,
    required this.el,
    required this.selected,
    required this.primary,
    required this.editing,
    required this.parentSize,
    required this.onSelect,
    required this.onPlayTap,
    required this.onMoveStart,
    required this.onMoveTo,
    required this.onResizeTo,
    required this.onGestureEnd,
    required this.onTextCommit,
  });

  final OverlayEl el;
  final bool selected;
  final bool primary;
  final bool editing;
  final Size parentSize;
  final VoidCallback onSelect;
  final VoidCallback onPlayTap;
  final VoidCallback onMoveStart;
  final void Function(double x, double y) onMoveTo;
  final void Function(double w, double h) onResizeTo;
  final VoidCallback onGestureEnd;
  final ValueChanged<String> onTextCommit;

  @override
  State<_CanvasItem> createState() => _CanvasItemState();
}

class _CanvasItemState extends State<_CanvasItem> {
  Offset? _pointerOrigin;
  double _originX = 0;
  double _originY = 0;
  double _originW = 0;
  double _originH = 0;
  bool _inlineEdit = false;
  late TextEditingController _textCtrl;

  static const _handle = 28.0;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.el.text ?? '');
  }

  @override
  void didUpdateWidget(covariant _CanvasItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.el.id != widget.el.id ||
        (!_inlineEdit && oldWidget.el.text != widget.el.text)) {
      _textCtrl.text = widget.el.text ?? '';
    }
    if (!widget.selected && _inlineEdit) _inlineEdit = false;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  TextAlign get _textAlign => switch (widget.el.align) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        _ => TextAlign.left,
      };

  Alignment get _boxAlign => switch (widget.el.align) {
        'center' => Alignment.center,
        'right' => Alignment.centerRight,
        _ => Alignment.topLeft,
      };

  FontWeight get _weight {
    const weights = <FontWeight>[
      FontWeight.w100,
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ];
    return weights[widget.el.fontWeight.clamp(0, weights.length - 1)];
  }

  BoxFit get _boxFit {
    switch (widget.el.fit) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      default:
        return BoxFit.cover;
    }
  }

  void _beginGesture(Offset global, {required bool forResize}) {
    if (!forResize) {
      widget.onMoveStart();
    }
    _pointerOrigin = global;
    _originX = widget.el.x;
    _originY = widget.el.y;
    _originW = widget.el.w;
    _originH = widget.el.h;
  }

  void _applyMove(Offset global) {
    final origin = _pointerOrigin;
    final pw = widget.parentSize.width;
    final ph = widget.parentSize.height;
    if (origin == null || pw <= 0 || ph <= 0) return;
    final dx = (global.dx - origin.dx) / pw * 100;
    final dy = (global.dy - origin.dy) / ph * 100;
    final maxX = math.max(0.0, 100 - _originW);
    final maxY = math.max(0.0, 100 - _originH);
    widget.onMoveTo(
      (_originX + dx).clamp(0, maxX),
      (_originY + dy).clamp(0, maxY),
    );
  }

  void _applyResize(Offset global) {
    final origin = _pointerOrigin;
    final pw = widget.parentSize.width;
    final ph = widget.parentSize.height;
    if (origin == null || pw <= 0 || ph <= 0) return;
    final dx = (global.dx - origin.dx) / pw * 100;
    final dy = (global.dy - origin.dy) / ph * 100;
    final maxW = math.max(4.0, 100 - _originX);
    final maxH = math.max(4.0, 100 - _originY);
    widget.onResizeTo(
      (_originW + dx).clamp(4, maxW),
      (_originH + dy).clamp(4, maxH),
    );
  }

  Widget _imageContent() {
    final el = widget.el;
    final src = el.src;
    if (src == null) {
      return const ColoredBox(color: Color(0x22000000));
    }

    Widget img;
    if (src.startsWith('assets/')) {
      img = Image.asset(
        src,
        fit: _boxFit,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
      );
    } else {
      img = Image.file(
        File(src),
        fit: _boxFit,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) =>
            const ColoredBox(color: Color(0x44000000)),
      );
    }

    final visibleW = (1 - el.cropL - el.cropR).clamp(0.2, 1.0);
    final visibleH = (1 - el.cropT - el.cropB).clamp(0.2, 1.0);
    final hasCrop = el.cropL + el.cropR + el.cropT + el.cropB > 0.001;
    if (!hasCrop) {
      return SizedBox.expand(child: img);
    }

    final midX = el.cropL + visibleW / 2;
    final midY = el.cropT + visibleH / 2;
    return ClipRect(
      child: SizedBox.expand(
        child: Align(
          alignment: Alignment(midX * 2 - 1, midY * 2 - 1),
          widthFactor: 1 / visibleW,
          heightFactor: 1 / visibleH,
          child: img,
        ),
      ),
    );
  }

  Widget _content() {
    final el = widget.el;
    final mod = el.module;
    final fg = parseCssColor(el.color) ?? PresentationTheme.ink;
    final bgRaw = el.bg;
    final bgTransparent =
        bgRaw == null || bgRaw.isEmpty || bgRaw == 'transparent';
    final bg = bgTransparent ? null : parseCssColor(bgRaw);
    final border = parseCssColor(el.borderColor);
    final radius = el.radius ?? (el.kind == OverlayKind.box ? 10.0 : 0.0);
    final pad = el.pad ?? (el.kind == OverlayKind.box ? 10.0 : 0.0);
    final BorderRadius borderRadius;
    if (mod == 'code_head' || el.id.endsWith('_codeHead')) {
      borderRadius = const BorderRadius.vertical(top: Radius.circular(14));
    } else if (mod == 'code_body' || el.id.endsWith('_codeBody')) {
      borderRadius = const BorderRadius.vertical(bottom: Radius.circular(14));
    } else if (mod == 'code_panel' || el.id.endsWith('_codePanel')) {
      borderRadius = BorderRadius.circular(14);
    } else {
      borderRadius = BorderRadius.circular(radius);
    }

    TextStyle textStyle({Color? color, double? size, FontWeight? weight}) =>
        TextStyle(
          color: color ?? fg,
          fontSize: size ?? el.fontSize ?? (el.kind == OverlayKind.box ? 16 : 20),
          fontWeight: weight ?? _weight,
          height: el.lineHeight ?? (el.kind == OverlayKind.box ? 1.3 : 1.25),
          fontFamily: el.fontFamily,
        );

    BoxDecoration boxDeco({Color? fill}) {
      final Color? c;
      if (fill != null) {
        c = fill;
      } else if (bgTransparent) {
        c = Colors.transparent;
      } else {
        c = bg ?? const Color(0xE0121A20);
      }
      return BoxDecoration(
        color: c,
        borderRadius: borderRadius,
        border: border == null ? null : Border.all(color: border),
      );
    }

    Widget editableOrText({
      required TextStyle style,
      TextAlign align = TextAlign.left,
      int? maxLines,
    }) {
      if (_inlineEdit && widget.editing) {
        return TextField(
          controller: _textCtrl,
          autofocus: true,
          maxLines: maxLines,
          textAlign: align,
          style: style,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: widget.onTextCommit,
          onSubmitted: (_) => setState(() => _inlineEdit = false),
        );
      }
      return Text(
        el.text ?? '',
        textAlign: align,
        softWrap: true,
        maxLines: maxLines,
        overflow: TextOverflow.visible,
        style: style,
      );
    }

    // --- Feste Module (1:1 wie SlideView) ---
    if (mod == 'hint') {
      return Container(
        clipBehavior: Clip.none,
        decoration: boxDeco(
          fill: bg ?? PresentationTheme.accent.withValues(alpha: 0.1),
        ),
        padding: EdgeInsets.all(pad),
        alignment: Alignment.topLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: PresentationTheme.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: editableOrText(
                style: textStyle(weight: FontWeight.w600, size: 13.5),
              ),
            ),
          ],
        ),
      );
    }

    if (mod == 'section_folder' || mod == 'section_book') {
      final icon = mod == 'section_folder'
          ? Icons.folder_open
          : Icons.menu_book_outlined;
      final label = (el.text ?? '').toUpperCase();
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, size: 15, color: PresentationTheme.accent),
            const SizedBox(width: 6),
            Flexible(
              child: _inlineEdit && widget.editing
                  ? TextField(
                      controller: _textCtrl,
                      autofocus: true,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: PresentationTheme.accent,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: widget.onTextCommit,
                      onSubmitted: (_) => setState(() => _inlineEdit = false),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: PresentationTheme.accent,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    if (mod == 'badge') {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg ?? PresentationTheme.accent,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: editableOrText(
          style: textStyle(color: Colors.white, size: 11, weight: FontWeight.w800),
          align: TextAlign.center,
          maxLines: 1,
        ),
      );
    }

    if (mod == 'tag') {
      return Container(
        alignment: Alignment.center,
        decoration: boxDeco(
          fill: bg ?? PresentationTheme.accent.withValues(alpha: 0.12),
        ),
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 2),
        child: editableOrText(
          style: textStyle(size: 11),
          align: TextAlign.center,
          maxLines: 1,
        ),
      );
    }

    if (mod == 'code_panel') {
      return DecoratedBox(decoration: boxDeco(fill: const Color(0xFF151A1F)));
    }

    if (mod == 'hud_panel' || mod == 'hud') {
      final lines = (el.text ?? '').split('\n');
      final head = lines.isNotEmpty ? lines.first : 'HUD / OLED';
      final title = lines.length > 2 ? lines[2] : 'WÄHLE DEIN PRODUKT';
      final sub = lines.length > 3 ? lines[3] : '';
      final foot = lines.length > 5
          ? lines[5]
          : (lines.length > 4 ? lines.last : '');
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F14),
          borderRadius: BorderRadius.circular(radius > 0 ? radius : 16),
          border: Border.all(
            color: border ?? const Color(0xB300F2FE),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
              blurRadius: 18,
            ),
          ],
        ),
        padding: EdgeInsets.all(pad > 0 ? pad : 16),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 280,
            height: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00F2FE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        head,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (_inlineEdit && widget.editing)
                  editableOrText(
                    style: textStyle(
                      color: const Color(0xFF00F2FE),
                      size: 18,
                      weight: FontWeight.w800,
                    ),
                    align: TextAlign.center,
                  )
                else ...[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF00F2FE),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  foot,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (mod == 'status_card') {
      final raw = el.text ?? '';
      final split = raw.indexOf('\n');
      final title = split < 0 ? raw : raw.substring(0, split);
      final detail = split < 0 ? '' : raw.substring(split + 1);
      final accent = border ?? PresentationTheme.accent;
      return Container(
        decoration: BoxDecoration(
          color: bg ?? Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(radius > 0 ? radius : 12),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        padding: EdgeInsets.all(pad > 0 ? pad : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (el.src != null && el.src!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  el.src!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 56,
                    height: 56,
                    color: accent.withValues(alpha: 0.12),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_outlined,
                      color: accent,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle(
                      weight: FontWeight.w700,
                      size: 14,
                      color: PresentationTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle(
                        size: 12.5,
                        color: PresentationTheme.muted,
                      ).copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (mod == 'video') {
      return Container(
        clipBehavior: Clip.none,
        decoration: boxDeco(fill: const Color(0xFF151A1F)),
        padding: EdgeInsets.all(pad),
        alignment: Alignment.center,
        child: editableOrText(
          style: textStyle(size: 13),
          align: TextAlign.center,
        ),
      );
    }

    if (mod == 'code_head') {
      return Container(
        decoration: boxDeco(fill: Colors.white.withValues(alpha: 0.06)),
        padding: EdgeInsets.all(pad),
        child: Row(
          children: [
            const Icon(Icons.code, size: 16, color: Color(0xFF7DDBD0)),
            const SizedBox(width: 8),
            const Text(
              'CODE',
              style: TextStyle(
                color: Color(0xFF7DDBD0),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: editableOrText(
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10.5,
                  fontFamily: 'Consolas',
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }

    if (mod == 'code_body') {
      return Container(
        alignment: Alignment.topLeft,
        padding: EdgeInsets.all(pad),
        child: editableOrText(
          style: textStyle(size: 12.5),
        ),
      );
    }

    switch (el.kind) {
      case OverlayKind.text:
        if (_inlineEdit && widget.editing) {
          return Container(
            color: bg ?? Colors.white70,
            padding: EdgeInsets.all(pad > 0 ? pad : 4),
            child: TextField(
              controller: _textCtrl,
              autofocus: true,
              maxLines: null,
              textAlign: _textAlign,
              style: textStyle(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onTextCommit,
              onSubmitted: (_) => setState(() => _inlineEdit = false),
            ),
          );
        }
        return SizedBox.expand(
          child: Align(
            alignment: _boxAlign,
            child: Text(
              el.text ?? '',
              textAlign: _textAlign,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: textStyle(),
            ),
          ),
        );
      case OverlayKind.box:
        final deco = boxDeco();
        if (_inlineEdit && widget.editing) {
          return Container(
            clipBehavior: Clip.none,
            decoration: deco,
            padding: EdgeInsets.all(pad),
            alignment: _boxAlign,
            child: TextField(
              controller: _textCtrl,
              autofocus: true,
              maxLines: null,
              textAlign: _textAlign,
              style: textStyle(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onTextCommit,
              onSubmitted: (_) => setState(() => _inlineEdit = false),
            ),
          );
        }
        final label = el.text ?? '';
        return Container(
          clipBehavior: Clip.none,
          alignment: _boxAlign,
          decoration: deco,
          padding: EdgeInsets.all(pad),
          child: label.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  label,
                  textAlign: _textAlign,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: textStyle(),
                ),
        );
      case OverlayKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(
            el.radius ?? (widget.el.fit == 'fill' ? 16 : 10),
          ),
          child: _imageContent(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.editing) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPlayTap,
        child: _content(),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              if (!widget.editing || _inlineEdit) return;
              widget.onSelect();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: (widget.el.kind == OverlayKind.text ||
                      widget.el.kind == OverlayKind.box)
                  ? () {
                      widget.onSelect();
                      setState(() {
                        _inlineEdit = true;
                        _textCtrl.text = widget.el.text ?? '';
                      });
                    }
                  : null,
              onPanStart: _inlineEdit
                  ? null
                  : (d) => _beginGesture(d.globalPosition, forResize: false),
              onPanUpdate: _inlineEdit
                  ? null
                  : (d) => _applyMove(d.globalPosition),
              onPanEnd: (_) {
                _pointerOrigin = null;
                widget.onGestureEnd();
              },
              onPanCancel: () {
                _pointerOrigin = null;
                widget.onGestureEnd();
              },
              child: _content(),
            ),
          ),
        ),
        if (widget.selected)
          Positioned(
            left: -1.5,
            top: -1.5,
            right: -1.5,
            bottom: -1.5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: PresentationTheme.accent
                        .withValues(alpha: widget.primary ? 1 : 0.65),
                    width: widget.primary ? 1.5 : 1.25,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
              ),
            ),
          ),
        if (widget.selected)
          Positioned(
            right: -2,
            bottom: -2,
            width: _handle,
            height: _handle,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) =>
                  _beginGesture(d.globalPosition, forResize: true),
              onPanUpdate: (d) => _applyResize(d.globalPosition),
              onPanEnd: (_) {
                _pointerOrigin = null;
                widget.onGestureEnd();
              },
              onPanCancel: () {
                _pointerOrigin = null;
                widget.onGestureEnd();
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PresentationTheme.accent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.south_east,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hilfslinie für Ausrichtung / Snap.
class _GuideLine {
  const _GuideLine({required this.vertical, required this.pos});
  final bool vertical;
  final double pos;
}

class _SnapResult {
  const _SnapResult({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.guides,
  });
  final double x;
  final double y;
  final double w;
  final double h;
  final List<_GuideLine> guides;
}

/// Magnetisches Einrasten an Leinwand und anderen Elementen.
class _CanvasSnap {
  static _SnapResult snapMove({
    required double x,
    required double y,
    required double w,
    required double h,
    required List<OverlayEl> others,
    required double threshold,
  }) {
    final xTargets = <double>[0, 50, 100];
    final yTargets = <double>[0, 50, 100];
    for (final o in others) {
      xTargets.addAll([o.x, o.x + o.w / 2, o.x + o.w]);
      yTargets.addAll([o.y, o.y + o.h / 2, o.y + o.h]);
    }

    var sx = x;
    var sy = y;
    double? bestXd;
    double? bestYd;

    for (final t in xTargets) {
      for (final cand in <(double edge, double apply)>[
        (x, t),
        (x + w / 2, t - w / 2),
        (x + w, t - w),
      ]) {
        final d = (cand.$1 - t).abs();
        if (d <= threshold && (bestXd == null || d < bestXd)) {
          bestXd = d;
          sx = cand.$2;
        }
      }
    }

    for (final t in yTargets) {
      for (final cand in <(double edge, double apply)>[
        (y, t),
        (y + h / 2, t - h / 2),
        (y + h, t - h),
      ]) {
        final d = (cand.$1 - t).abs();
        if (d <= threshold && (bestYd == null || d < bestYd)) {
          bestYd = d;
          sy = cand.$2;
        }
      }
    }

    sx = sx.clamp(0.0, math.max(0.0, 100 - w));
    sy = sy.clamp(0.0, math.max(0.0, 100 - h));

    return _SnapResult(
      x: sx,
      y: sy,
      w: w,
      h: h,
      guides: _collectGuides(sx, sy, w, h, xTargets, yTargets),
    );
  }

  static _SnapResult snapResize({
    required double x,
    required double y,
    required double w,
    required double h,
    required List<OverlayEl> others,
    required double threshold,
  }) {
    var sw = w;
    var sh = h;
    double? bestWd;
    double? bestHd;

    for (final o in others) {
      final dw = (w - o.w).abs();
      if (dw <= threshold && (bestWd == null || dw < bestWd)) {
        bestWd = dw;
        sw = o.w;
      }
      final dh = (h - o.h).abs();
      if (dh <= threshold && (bestHd == null || dh < bestHd)) {
        bestHd = dh;
        sh = o.h;
      }
    }

    final xTargets = <double>[0, 50, 100];
    final yTargets = <double>[0, 50, 100];
    for (final o in others) {
      xTargets.addAll([o.x, o.x + o.w / 2, o.x + o.w]);
      yTargets.addAll([o.y, o.y + o.h / 2, o.y + o.h]);
    }

    final right = x + sw;
    final bottom = y + sh;
    double? bestRd;
    double? bestBd;
    var finalW = sw;
    var finalH = sh;

    for (final t in xTargets) {
      final d = (right - t).abs();
      if (d <= threshold && (bestRd == null || d < bestRd)) {
        bestRd = d;
        finalW = (t - x).clamp(4.0, 100 - x);
      }
    }
    for (final t in yTargets) {
      final d = (bottom - t).abs();
      if (d <= threshold && (bestBd == null || d < bestBd)) {
        bestBd = d;
        finalH = (t - y).clamp(3.0, 100 - y);
      }
    }

    if (bestWd != null && (bestRd == null || bestWd <= bestRd)) {
      finalW = sw;
    }
    if (bestHd != null && (bestBd == null || bestHd <= bestBd)) {
      finalH = sh;
    }

    return _SnapResult(
      x: x,
      y: y,
      w: finalW,
      h: finalH,
      guides: _collectGuides(x, y, finalW, finalH, xTargets, yTargets),
    );
  }

  static List<_GuideLine> _collectGuides(
    double x,
    double y,
    double w,
    double h,
    List<double> xTargets,
    List<double> yTargets,
  ) {
    const eps = 0.12;
    final guides = <_GuideLine>[];
    final seenV = <String>{};
    final seenH = <String>{};

    void addV(double pos) {
      final key = pos.toStringAsFixed(2);
      if (seenV.add(key)) {
        guides.add(_GuideLine(vertical: true, pos: pos));
      }
    }

    void addH(double pos) {
      final key = pos.toStringAsFixed(2);
      if (seenH.add(key)) {
        guides.add(_GuideLine(vertical: false, pos: pos));
      }
    }

    final edgesX = [x, x + w / 2, x + w];
    final edgesY = [y, y + h / 2, y + h];

    for (final t in xTargets) {
      for (final e in edgesX) {
        if ((e - t).abs() <= eps) addV(t);
      }
    }
    for (final t in yTargets) {
      for (final e in edgesY) {
        if ((e - t).abs() <= eps) addH(t);
      }
    }
    return guides;
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.guides});

  final List<_GuideLine> guides;
  static const _color = Color(0xFFFF2D95);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = _color
      ..style = PaintingStyle.fill;

    for (final g in guides) {
      if (g.vertical) {
        final x = g.pos / 100 * size.width;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);
        canvas.drawCircle(Offset(x, size.height / 2), 3, fill);
      } else {
        final y = g.pos / 100 * size.height;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
        canvas.drawCircle(Offset(size.width / 2, y), 3, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) {
    if (oldDelegate.guides.length != guides.length) return true;
    for (var i = 0; i < guides.length; i++) {
      final a = guides[i];
      final b = oldDelegate.guides[i];
      if (a.vertical != b.vertical || a.pos != b.pos) return true;
    }
    return false;
  }
}

class _MarqueePainter extends CustomPainter {
  _MarqueePainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTRB(
      rect.left / 100 * size.width,
      rect.top / 100 * size.height,
      rect.right / 100 * size.width,
      rect.bottom / 100 * size.height,
    );
    final fill = Paint()
      ..color = PresentationTheme.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final stroke = Paint