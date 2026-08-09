import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/hold_nav.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/overlay_models.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/presentation_store.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/slide_editor.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/slide_materialize.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/slide_widgets.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/slides.dart';

/// Flutter-Präsentation: Abspielen + Bearbeiten auf derselben 16:9-Canvas.
class PresentationScreen extends StatefulWidget {
  const PresentationScreen({super.key});

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  final _slides = kPresentationSlides;
  int _index = 0;
  bool _editing = false;
  DateTime? _startedAt;
  DateTime _now = DateTime.now();
  Timer? _clock;
  OverlayDoc _overlays = {};
  /// Letzter gespeicherter Stand (für Verwerfen).
  OverlayDoc _savedSnapshot = {};
  bool _dirty = false;
  /// Erhöht bei Save/Commit — veraltetes async Load darf nicht überschreiben.
  int _storeEpoch = 0;
  final _focus = FocusNode();
  final _canvasKey = GlobalKey<SlideCanvasState>();
  final _canvasController = SlideCanvasController();

  /// Aktuelle Bearbeitungs-Kopie der Folie (Texte/Bilder als Elemente).
  List<OverlayEl>? _editSession;

  PresentationSlide get _slide =>
      _slides[_index.clamp(0, _slides.length - 1)];

  /// Play und Bearbeiten: immer dieselbe Canvas-Quelle (1:1).
  List<OverlayEl> get _elements {
    if (_editing) {
      return List<OverlayEl>.from(
        _editSession ?? _loadEditSessionFor(_slide),
      );
    }
    return List<OverlayEl>.from(_loadEditSessionFor(_slide));
  }

  /// Bearbeiten: gespeichertes Layout laden, sonst Standard-Module materialisieren.
  /// Alte Code-Layouts ohne codeBody werden frisch materialisiert (Text bleibt).
  List<OverlayEl> _loadEditSessionFor(PresentationSlide slide) {
    final saved = _overlays[slide.id];
    final factory = materializeSlide(slide);
    final factoryIds = factory.map((e) => e.id).toSet();

    if (saved == null || saved.isEmpty) return factory;

    final stickers = saved
        .where((e) => !factoryIds.contains(e.id) && !_isLegacyFactoryId(e.id, slide))
        .map((e) => e.copy())
        .toList();

    final hasCleanCode = slide is! CodeSlide ||
        saved.any((e) =>
            e.id.endsWith('_codeBody') || e.module == 'code_body');
    final hasAnyFactory = saved.any((e) => factoryIds.contains(e.id));

    // Alte Saves / ohne Modul-Metadaten → frisches sauberes Layout
    final needsFreshCode = slide is CodeSlide &&
        (!hasCleanCode ||
            !saved.any((e) => e.module == 'hint' || e.module == 'code_head'));
    // Alte mehrteilige HUDs / 5. Phase / ohne Detail → neu materialisieren
    final needsFreshFlow = slide is FlowSlide &&
        (!saved.any((e) => e.module == 'hud') ||
            saved.any((e) => e.id.endsWith('_step4')) ||
            !saved.any((e) => e.id.endsWith('_detail')));
    // Alte Status-Layouts: falsche IST/SOLL-Farben oder lose Texte statt Karten
    final needsFreshStatus = slide is StatusSlide &&
        (!saved.any((e) => e.module == 'status_card') ||
            saved.any((e) =>
                e.id.endsWith('_nowH') &&
                (e.color?.toUpperCase() == '#C45C26')) ||
            saved.any((e) =>
                e.id.endsWith('_nextH') &&
                (e.color?.toUpperCase() == '#1F8F84')));

    if (!hasAnyFactory ||
        needsFreshCode ||
        needsFreshFlow ||
        needsFreshStatus) {
      return _mergeTextOntoFactory(factory, saved)..addAll(stickers);
    }

    // Gespeicherte Maße 1:1 übernehmen — kein Auto-Fit.
    return saved.map((e) => e.copy()).toList();
  }

  bool _isLegacyFactoryId(String id, PresentationSlide slide) {
    final prefix = '${slide.id}_';
    if (!id.startsWith(prefix)) return false;
    final suffix = id.substring(prefix.length);
    return suffix == 'code' ||
        suffix.startsWith('ex') ||
        suffix.startsWith('tag') ||
        const {
          'kicker',
          'title',
          'summary',
          'file',
          'fileLabel',
          'exLabel',
        }.contains(suffix);
  }

  /// Frisches Layout, Texte aus altem Save übernehmen (gleiche Suffix-IDs).
  List<OverlayEl> _mergeTextOntoFactory(
    List<OverlayEl> factory,
    List<OverlayEl> saved,
  ) {
    String suffix(String id) {
      final i = id.lastIndexOf('_');
      return i < 0 ? id : id.substring(i + 1);
    }

    final bySuffix = <String, OverlayEl>{};
    for (final e in saved) {
      bySuffix[suffix(e.id)] = e;
    }
    // Altes einteiliges Code-Feld → codeBody
    final legacyCode = bySuffix['code'];
    return factory.map((el) {
      final c = el.copy();
      final prev = bySuffix[suffix(el.id)];
      if (prev?.text != null && prev!.text!.isNotEmpty) {
        var t = prev.text!;
        // Alte Emoji-/CODE-Prefixes entfernen
        t = t.replaceFirst(RegExp(r'^[💡📁📖<>\s]+'), '');
        t = t.replaceFirst(RegExp(r'^CODE\s+'), '');
        c.text = t;
      } else if (suffix(el.id) == 'codeBody' && legacyCode?.text != null) {
        final raw = legacyCode!.text!;
        c.text = raw.contains('\n\n')
            ? raw.split('\n\n').skip(1).join('\n\n')
            : raw.replaceFirst(RegExp(r'^CODE[^\n]*\n*'), '');
      }
      return c;
    }).toList();
  }

  OverlayDoc _sanitizeOverlays(OverlayDoc doc) {
    return {
      for (final e in doc.entries)
        if (e.value.isNotEmpty)
          e.key: e.value.map((el) => el.copy()).toList(),
    };
  }

  OverlayDoc _cloneDoc(OverlayDoc doc) {
    return {
      for (final e in doc.entries)
        e.key: e.value.map((el) => el.copy()).toList(),
    };
  }

  @override
  void initState() {
    super.initState();
    _canvasController.addListener(() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    });
    _clock = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final epoch = _storeEpoch;
    final doc = _sanitizeOverlays(await PresentationStore.loadOverlays());
    if (!mounted || epoch != _storeEpoch) return;
    setState(() {
      _overlays = doc;
      _savedSnapshot = _cloneDoc(doc);
      _dirty = false;
      if (_editing) {
        _editSession = _loadEditSessionFor(_slide);
      }
    });
    unawaited(PresentationStore.saveOverlays(doc));
  }

  Future<void> _save() async {
    if (_editing && _editSession != null) {
      final next = Map<String, List<OverlayEl>>.from(_overlays);
      if (_editSession!.isEmpty) {
        next.remove(_slide.id);
      } else {
        next[_slide.id] = _editSession!.map((e) => e.copy()).toList();
      }
      _overlays = next;
    }
    _storeEpoch++;
    final epoch = _storeEpoch;
    await PresentationStore.saveOverlays(_overlays);
    if (!mounted || epoch != _storeEpoch) return;
    setState(() {
      _dirty = false;
      _savedSnapshot = _cloneDoc(_overlays);
      // Session unverändert lassen — kein Reload/Fit, der die Breite zurücksetzt.
      if (_editing && _editSession == null) {
        _editSession = _loadEditSessionFor(_slide);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Präsentation gespeichert'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _commitElements(List<OverlayEl> els) {
    _storeEpoch++;
    setState(() {
      _editSession = els;
      final next = Map<String, List<OverlayEl>>.from(_overlays);
      if (els.isEmpty) {
        next.remove(_slide.id);
      } else {
        next[_slide.id] = els.map((e) => e.copy()).toList();
      }
      _overlays = next;
      _dirty = true;
    });
  }

  void _resetSlide() {
    setState(() {
      _overlays = Map<String, List<OverlayEl>>.from(_overlays)
        ..remove(_slide.id);
      _editSession = materializeSlide(_slide);
      _dirty = true;
    });
  }

  void _addOverlay(OverlayEl el) {
    _commitElements([..._elements, el]);
  }

  void _addOverlays(List<OverlayEl> els) {
    if (els.isEmpty) return;
    final s = _canvasKey.currentState;
    if (s != null) {
      s.addElements(els);
      return;
    }
    _commitElements([..._elements, ...els]);
  }

  Future<void> _pickOverlayImage() async {
    final s = _canvasKey.currentState;
    if (s != null) {
      await s.pickImage();
      return;
    }
    await Future<void>.delayed(Duration.zero);
    await _canvasKey.currentState?.pickImage();
  }

  void _exitEditingClean() {
    setState(() {
      _editing = false;
      _editSession = null;
    });
  }

  void _discardAndExitEditing() {
    setState(() {
      _overlays = _cloneDoc(_savedSnapshot);
      _dirty = false;
      _editing = false;
      _editSession = null;
    });
  }

  Future<_EditExitAction?> _askUnsavedChanges() {
    return showDialog<_EditExitAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ungespeicherte Änderungen'),
        content: const Text(
          'Du hast die Folie geändert. Speichern, verwerfen oder weiter bearbeiten?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _EditExitAction.cancel),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _EditExitAction.discard),
            child: const Text('Verwerfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _EditExitAction.save),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestExitEditing() async {
    if (!_dirty) {
      _exitEditingClean();
      return;
    }
    final action = await _askUnsavedChanges();
    if (!mounted) return;
    switch (action) {
      case _EditExitAction.save:
        await _save();
        if (!mounted) return;
        _exitEditingClean();
      case _EditExitAction.discard:
        _discardAndExitEditing();
      case _EditExitAction.cancel:
      case null:
        // Im Bearbeiten-Modus bleiben (SegmentedButton bleibt auf Bearbeiten).
        setState(() => _editing = true);
    }
  }

  void _setEditing(bool value) {
    if (value == _editing) return;
    if (value) {
      setState(() {
        _editing = true;
        _editSession = _loadEditSessionFor(_slide);
      });
      return;
    }
    unawaited(_requestExitEditing());
  }

  void _go(int next) {
    setState(() {
      _index = next.clamp(0, _slides.length - 1);
      _startedAt ??= DateTime.now();
      if (_editing) {
        _editSession = _loadEditSessionFor(_slides[_index]);
      }
    });
  }

  Future<void> _maybeLeave() async {
    if (_editing && _dirty) {
      final action = await _askUnsavedChanges();
      if (!mounted) return;
      switch (action) {
        case _EditExitAction.save:
          await _save();
          if (!mounted) return;
          _exitEditingClean();
        case _EditExitAction.discard:
          _discardAndExitEditing();
        case _EditExitAction.cancel:
        case null:
          return;
      }
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_editing) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(_maybeLeave());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _go(_index + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _go(_index - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _focus.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  String _timerLabel() {
    if (_startedAt == null) return '5:30';
    final elapsed = _now.difference(_startedAt!);
    final left = kPresentationTotal - elapsed;
    if (left <= Duration.zero) return '0:00';
    final m = left.inMinutes;
    final s = left.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _overtime {
    if (_startedAt == null) return false;
    return _now.difference(_startedAt!) >= kPresentationTotal;
  }

  OverlayEl? get _selectedEl {
    final id = _canvasController.selectedId;
    if (id == null) return null;
    for (final e in _elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _editUndo() {
    _canvasKey.currentState?.undo();
    setState(() {});
  }

  void _editRedo() {
    _canvasKey.currentState?.redo();
    setState(() {});
  }

  bool _focusIsTextEditing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null ||
        ctx.findAncestorWidgetOfExactType<TextField>() != null ||
        ctx.findAncestorWidgetOfExactType<TextFormField>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_index + 1) / _slides.length;
    final canvas = _canvasKey.currentState;

    return CallbackShortcuts(
      bindings: {
        if (_editing) ...{
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              _editUndo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): _editRedo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true):
              _editRedo,
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _editUndo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: true,
            shift: true,
          ): _editRedo,
          const SingleActivator(LogicalKeyboardKey.keyY, meta: true): _editRedo,
          const SingleActivator(LogicalKeyboardKey.keyC, control: true): () {
            if (_focusIsTextEditing()) return;
            unawaited(
              _canvasKey.currentState?.copySelection() ?? Future.value(),
            );
          },
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () {
            if (_focusIsTextEditing()) return;
            unawaited(
              _canvasKey.currentState?.pasteClipboard() ?? Future.value(),
            );
          },
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
            if (_focusIsTextEditing()) return;
            _canvasKey.currentState?.selectAll();
          },
        },
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: PresentationTheme.stage,
          body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/presentation/brand/marble-soft.png',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.35),
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: PresentationTheme.stage),
              ),
            ),
            Positioned.fill(
              child: Padding(
                // Im Bearbeiten: rechts Platz für Studio, Folie wird nicht überdeckt.
                padding: EdgeInsets.fromLTRB(
                  12,
                  56,
                  _editing ? 300 : 12,
                  72,
                ),
                child: SlideStage(
                  child: SlideCanvas(
                    key: _canvasKey,
                    editing: _editing,
                    elements: _elements,
                    controller: _canvasController,
                    onChange: _commitElements,
                  ),
                ),
              ),
            ),
            if (_editing)
              Positioned(
                top: 56,
                right: 12,
                bottom: 72,
                width: 280,
                child: PresentationEditorDock(
                  selected: _selectedEl ?? canvas?.selectedEl,
                  onAddText: () {
                    final s = _canvasKey.currentState;
                    if (s != null) {
                      s.addText();
                    } else {
                      _addOverlay(createTextOverlay());
                    }
                  },
                  onAddBox: () {
                    final s = _canvasKey.currentState;
                    if (s != null) {
                      s.addBox();
                    } else {
                      _addOverlay(createBoxOverlay());
                    }
                  },
                  onAddHint: () {
                    final s = _canvasKey.currentState;
                    if (s != null) {
                      s.addHintModule();
                    } else {
                      _addOverlay(createHintModule());
                    }
                  },
                  onAddStep: () {
                    final s = _canvasKey.currentState;
                    if (s != null) {
                      s.addStepModule();
                    } else {
                      _addOverlays(createStepModule());
                    }
                  },
                  onAddSection: () {
                    final s = _canvasKey.currentState;
                    if (s != null) {
                      s.addSectionModule();
                    } else {
                      _addOverlay(createSectionModule());
                    }
                  },
                  onAddTitleBody: () {
                    final s = _canvasKey.currentState;
                    if (s != null) {
                      s.addTitleBodyModule();
                    } else {
                      _addOverlays(createTitleBodyModule());
                    }
                  },
                  onPickImage: () => unawaited(_pickOverlayImage()),
                  onReset: _resetSlide,
                  onDelete: () => _canvasKey.currentState?.removeSelected(),
                  onBringForward: () =>
                      _canvasKey.currentState?.bringSelectedForward(),
                  onPatch: (patch) =>
                      _canvasKey.currentState?.updateSelected(patch),
                  canUndo: canvas?.canUndo ?? false,
                  canRedo: canvas?.canRedo ?? false,
                  onUndo: _editUndo,
                  onRedo: _editRedo,
                ),
              ),
            if (!_editing)
              Positioned(
                top: 56,
                left: 0,
                right: 0,
                bottom: 0,
                child: HoldNav(
                  enabled: true,
                  canForward: _index < _slides.length - 1,
                  canBack: _index > 0,
                  onForward: () => _go(_index + 1),
                  onBack: () => _go(_index - 1),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: PresentationTheme.stage.withValues(alpha: 0.92),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Zurück',
                          onPressed: () => unawaited(_maybeLeave()),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Text(
                          '${_index + 1} / ${_slides.length}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.black12,
                              color: PresentationTheme.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _timerLabel(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _overtime
                                ? const Color(0xFFE85A5A)
                                : PresentationTheme.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_editing) ...[
                          TextButton(
                            onPressed:
                                _dirty ? () => unawaited(_save()) : null,
                            child:
                                Text(_dirty ? 'Speichern*' : 'Gespeichert'),
                          ),
                        ],
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Abspielen'),
                              icon: Icon(Icons.play_arrow, size: 18),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Bearbeiten'),
                              icon: Icon(Icons.edit, size: 18),
                            ),
                          ],
                          selected: {_editing},
                          onSelectionChanged: (s) => _setEditing(s.first),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!_editing && _slide.speakHint.isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 48,
                child: IgnorePointer(
                  child: Text(
                    _slide.speakHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.35),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

enum _EditExitAction { save, discard, cancel }
