import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import '../models/power3d_model.dart';
import 'asset_manager.dart';

part 'view_extension.dart';
part 'selection_extension.dart';
part 'material_extension.dart';
part 'texture_extension.dart';
part 'animation_extension.dart';
part 'annotation_extension.dart';
part 'projection_extension.dart';

/// Controller zur programmatischen Steuerung des [Power3D]-Viewers.
///
/// Damit kannst du Modelle laden, Materialien ändern, Screenshots aufnehmen,
/// die Beleuchtung verwalten und die Kamera steuern.
class Power3DController extends ValueNotifier<Power3DState> {
  /// Erstellt einen neuen [Power3DController] mit Initialzustand.
  Power3DController() : super(Power3DState.initial());

  InAppWebViewController? _webViewController;

  bool _isDisposed = false;
  bool _projectionHelpersInjected = false;
  final Map<String, Completer<String?>> _textureCompleters = {};
  String? _pendingScreenshotPath;
  Function(String partName, bool selected)? _onPartSelectedCallback;
  /// Wird ausgelöst, wenn der Button „Learn More“ oder „Details“ einer Annotation angeklickt wird.
  /// Weitergeleitet aus der JavaScript-Bridge.
  Function(String id, Map<String, dynamic> data)? onAnnotationMoreCallback;

  /// Anpassbarer Hook zum Auflösen nicht-stringbasierter Annotationsstile.
  static Future<void> Function(Power3DController controller, dynamic style)? globalStyleResolver;

  Future<void> Function(dynamic style)? _onResolveStyle;
  Future<void> Function(dynamic style)? get onResolveStyle => _onResolveStyle;
  set onResolveStyle(Future<void> Function(dynamic style)? hook) {
    if (_onResolveStyle == hook) return;
    _onResolveStyle = hook;
    
    // Wenn gerade ein Hook gesetzt wurde und ein ausstehender Nicht-String-Stil (Enum/Objekt) vorliegt, auflösen!
    if (hook != null && value.annotationStyle != null && value.annotationStyle is! String) {
      setAnnotationStyle(value.annotationStyle);
    }
  }

  /// Interne Methode zum Setzen des WebView-Controllers.
  /// Sollte nur vom Power3D-Widget verwendet werden.
  @internal
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  bool get _alive =>
      !_isDisposed && _webViewController != null && value.isInitialized;

  Future<dynamic> _evalJs(String source) async {
    if (_webViewController == null || _isDisposed) return null;
    try {
      return await _webViewController!.evaluateJavascript(source: source);
    } catch (error) {
      debugPrint('Power3D _evalJs failed: $error');
      return null;
    }
  }

  /// Interne Initialisierungslogik, die den Standard-[Power3DState]
  /// mit der darunterliegenden Babylon.js-Engine synchronisiert, sobald die WebView bereit ist.
  /// 
  /// Dabei werden initiale Beleuchtung, Materialien, Schattierungsmodi und
  /// Selection-Konfigurationen angewendet.
  void initialize() {
    if (value.isInitialized) return;
    value = value.copyWith(isInitialized: true);

    // Initiale Beleuchtung anwenden
    setLights(value.lights);
    updateSceneProcessing(exposure: value.exposure, contrast: value.contrast);

    // Initiale Materialien/Schattierung anwenden
    setShadingMode(value.shadingMode);
    if (value.globalMaterial != null) {
      setGlobalMaterial(value.globalMaterial!);
    }

    // Selection-Konfiguration anwenden
    updateSelectionConfig(value.selectionConfig);

    // Initiale Annotationen anwenden
    if (value.annotations != null) {
      debugPrint(
        'Power3D: initialize - applying ${value.annotations!.length} chars of annotation data',
      );
      setAnnotations(value.annotations!);
    }
    if (value.annotationStyle != null) {
      setAnnotationStyle(value.annotationStyle!, force: true);
    }

    // Kameraposition synchronisieren
    unawaited(
      _webViewController?.evaluateJavascript(
        source:
            'setCameraPosition(${value.cameraAlpha}, ${value.cameraBeta}, ${value.cameraRadius})',
      ),
    );

    // Initiale Zoom-Empfindlichkeit anwenden
    unawaited(updateZoomSensitivity(value.zoomSensitivity));
  }

  /// Lädt ein 3D-Modell in die Szene.
  /// 
  /// Der Parameter [data] gibt die Quelle an (Asset, Netzwerk oder Datei).
  /// Bei großen Modellen übernimmt diese Methode Base64-Kodierung für lokale Dateien
  /// und direktes URL-Laden für Netzwerkquellen.
  Future<void> loadModel(Power3DData data) async {
    if (!value.isInitialized || _webViewController == null) return;

    value = value.copyWith(
      status: Power3DStatus.loading,
      currentModelName: data.fileName ?? p.basename(data.path),
    );

    try {
      String encodedData;
      String type = 'url';
      String fileName = data.fileName ?? p.basename(data.path);

      switch (data.source) {
        case Power3DSource.asset:
          // Relative URL neben index.html — deutlich schneller als ~85MB Base64-IPC.
          encodedData = await Power3DAssetManager.ensureAssetModelUrl(data.path);
          type = 'url';
          break;
        case Power3DSource.network:
          encodedData = data.path;
          type = 'url';
          break;
        case Power3DSource.file:
          encodedData = await Power3DAssetManager.ensureFileModelUrl(data.path);
          type = 'url';
          break;
      }

      final safeUrl = encodedData.replaceAll(r'\', '/').replaceAll('"', r'\"');
      final safeName = fileName.replaceAll('"', r'\"');
      await _webViewController!.evaluateJavascript(
        source: 'loadModel("$safeUrl", "$safeName", "$type")',
      );
    } catch (e) {
      value = value.copyWith(
        status: Power3DStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Die primäre Kommunikationsbrücke, die rohe JSON-Nachrichten
  /// von der JavaScript-Engine empfängt und in [Power3DState]-Updates übersetzt.
  @internal
  void handleWebViewMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'status') {
        if (data['message'] == 'loaded') {
          value = value.copyWith(status: Power3DStatus.loaded);
          // Materialien und Schattierung nach dem Modellladen erneut anwenden
          setShadingMode(value.shadingMode);
          if (value.globalMaterial != null) {
            setGlobalMaterial(value.globalMaterial!);
          }
          // Selection-Konfiguration erneut anwenden
          updateSelectionConfig(value.selectionConfig);
          // Kameraposition synchronisieren
          unawaited(
            _webViewController?.evaluateJavascript(
              source:
                  'setCameraPosition(${value.cameraAlpha}, ${value.cameraBeta}, ${value.cameraRadius})',
            ),
          );
          // Animationen initialisieren
          unawaited(
            _webViewController?.evaluateJavascript(source: 'initAnimations()'),
          );
        } else if (data['message'] == 'reset') {
          value = value.copyWith(
            selectedParts: [],
            hiddenParts: [],
            boundingBoxParts: [],
          );
          // Animationsliste aktualisieren, um isPlaying-Status zu synchronisieren
          unawaited(getAnimationsList());
        } else if (data['message'] == 'loading') {
          value = value.copyWith(status: Power3DStatus.loading);
        }
      } else if (data['type'] == 'statusChange') {
        // Interne Status-Updates von JS (z. B. Rotation gestoppt)
        final key = data['key'];
        final val = data['value'];
        if (key == 'autoRotate') {
          value = value.copyWith(autoRotate: val);
        }
      } else if (data['type'] == 'error') {
        value = value.copyWith(
          status: Power3DStatus.error,
          errorMessage: data['message'],
        );
      } else if (data['type'] == 'camera') {
        value = value.copyWith(
          cameraAlpha: (data['alpha'] as num).toDouble(),
          cameraBeta: (data['beta'] as num).toDouble(),
          cameraRadius: (data['radius'] as num).toDouble(),
        );
      } else if (data['type'] == 'textureData') {
        final id = data['uniqueId'].toString();
        final base64Data = data['data'];
        if (_textureCompleters.containsKey(id)) {
          _textureCompleters[id]!.complete(base64Data);
          _textureCompleters.remove(id);
        }
      } else if (data['type'] == 'screenshot') {
        final String base64Data = data['data'];
        value = value.copyWith(lastScreenshot: base64Data);

        if (_pendingScreenshotPath != null) {
          _saveScreenshotToFile(base64Data, _pendingScreenshotPath!);
          _pendingScreenshotPath = null;
        }
      } else if (data['type'] == 'partSelected') {
        final String partName = data['partName'];
        final bool selected = data['selected'];

        _onPartSelectedCallback?.call(partName, selected);

        final newSelected = List<String>.from(value.selectedParts);
        if (selected) {
          if (!newSelected.contains(partName)) newSelected.add(partName);
        } else {
          newSelected.remove(partName);
        }
        value = value.copyWith(selectedParts: newSelected);
      } else if (data['type'] == 'partsList') {
        final List<String> parts = (data['parts'] as List).cast<String>();
        value = value.copyWith(availableParts: parts);
      } else if (data['type'] == 'animationsList') {
        final List<Power3DAnimation> animations = (data['animations'] as List)
            .map((e) => Power3DAnimation.fromJson(e))
            .toList();
        value = value.copyWith(animations: animations);
      } else if (data['type'] == 'animationStatus') {
        final updatedAnim = Power3DAnimation.fromJson(data['animation']);
        final newAnimations = value.animations.map((a) {
          return a.name == updatedAnim.name ? updatedAnim : a;
        }).toList();
        value = value.copyWith(animations: newAnimations);
      } else if (data['type'] == 'annotationMore') {
        final id = data['id'].toString();
        final Map<String, dynamic> annotationData = Map<String, dynamic>.from(
          data['data'],
        );
        onAnnotationMoreCallback?.call(id, annotationData);
      }
    } catch (e) {
      // Parse-Fehler von JS ignorieren
    }
  }

  Power3DState? _pendingValue;

  @override
  Power3DState get value => _pendingValue ?? super.value;

  /// Aktualisiert den Zustand des Controllers.
  /// 
  /// Dieser Override stellt sicher, dass Benachrichtigungen sicher behandelt werden,
  /// insbesondere wenn asynchrone WebView-Ereignisse während einer Flutter-Build-Phase
  /// eintreffen.
  /// 
  /// Wir nutzen ein „Pending-Value“-Muster, damit State-Updates für sequenzielle Logik
  /// (z. B. Initialisierung) synchron bleiben, während die eigentlichen
  /// Benachrichtigungen auf den nächsten Microtask verschoben werden, wenn das Framework busy ist.
  @override
  set value(Power3DState newValue) {
    if (_isDisposed || value == newValue) return;

    final widgetsBinding = WidgetsBinding.instance;
    // SchedulerPhase.persistentCallbacks entspricht Build-, Layout- und Paint-Phasen.
    if (widgetsBinding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_pendingValue == null) {
        scheduleMicrotask(() {
          if (!_isDisposed && _pendingValue != null) {
            final val = _pendingValue!;
            _pendingValue = null;
            // super.value = val löst notifyListeners() außerhalb der Build-Phase aus.
            super.value = val;
          }
        });
      }
      _pendingValue = newValue; // Sofort aktualisieren für lokale Controller-Logik.
    } else {
      _pendingValue = null;
      super.value = newValue;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _webViewController = null;
    for (var completer in _textureCompleters.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _textureCompleters.clear();
    super.dispose();
  }

  /// Holt die Daten einer bestimmten Annotation anhand ihrer [id].
  Future<Map<String, dynamic>?> getAnnotationData(String id) async {
    if (!value.isInitialized || _webViewController == null) return null;
    try {
      final String? result = await _webViewController!.evaluateJavascript(
        source: 'getAnnotationData("$id")',
      );
      if (result != null && result.isNotEmpty && result != "null") {
        return jsonDecode(result);
      }
    } catch (e) {
      debugPrint('Power3DController: Error getting annotation data: $e');
    }
    return null;
  }
}
