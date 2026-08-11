part of 'power3d_controller.dart';

/// Material- und Beleuchtungs-Erweiterung für [Power3DController].
extension MaterialExtension on Power3DController {
  /// Aktualisiert den Schattierungs- und Rendermodus der 3D-Szene (z. B. [ShadingMode.wireframe]).
  Future<void> setShadingMode(ShadingMode mode) async {
    value = value.copyWith(shadingMode: mode);
    if (_webViewController == null) return;
    await _webViewController!.evaluateJavascript(
      source: 'updateShadingMode("${mode.name}")',
    );
  }

  /// Aktualisiert die globalen Materialeigenschaften für das gesamte Modell.
  ///
  /// Damit können Farben, Metallic-/Roughness-Eigenschaften und Alpha überschrieben werden.
  Future<void> setGlobalMaterial(MaterialConfig config) async {
    value = value.copyWith(globalMaterial: config);
    if (_webViewController == null) return;

    final String? colorHex = config.color != null
        ? '#${config.color!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}'
        : null;
    final String? emissiveHex = config.emissiveColor != null
        ? '#${config.emissiveColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}'
        : null;

    final Map<String, dynamic> jsConfig = {
      'color': colorHex,
      'metallic': config.metallic,
      'roughness': config.roughness,
      'alpha': config.alpha,
      'emissiveColor': emissiveHex,
      'doubleSided': config.doubleSided,
    };

    await _webViewController!.evaluateJavascript(
      source: 'updateGlobalMaterial(${jsonEncode(jsConfig)})',
    );
  }

  /// Setzt die Beleuchtungskonfiguration der Szene.
  ///
  /// Ersetzt vorhandene Lichter durch die bereitgestellte Liste von [LightingConfig]s.
  Future<void> setLights(List<LightingConfig> lightsList) async {
    value = value.copyWith(lights: lightsList);

    if (_webViewController == null) return;

    final List<Map<String, dynamic>> jsConfigs = lightsList.map((config) {
      final colorHex =
          '#${config.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      final Map<String, dynamic> jsConfig = {
        'type': config.type.name,
        'intensity': config.intensity,
        'color': colorHex,
        'castShadows': config.castShadows,
        'shadowBlur': config.shadowBlur,
      };

      if (config.direction != null) {
        jsConfig['direction'] = {
          'x': config.direction!.x,
          'y': config.direction!.y,
        };
      }
      return jsConfig;
    }).toList();

    await _webViewController!.evaluateJavascript(
      source: 'updateLighting(${jsonEncode(jsConfigs)})',
    );
  }

  @Deprecated('Use setLights instead')
  Future<void> updateLighting(LightingConfig config) async {
    await setLights([config]);
  }

  /// Aktualisiert die szenenweite Bildverarbeitung (Exposure und Kontrast).
  ///
  /// [exposure]: Licht-Exposure-Stufe in der Szene.
  /// [contrast]: Unterschied zwischen hellen und dunklen Bereichen.
  Future<void> updateSceneProcessing({
    double? exposure,
    double? contrast,
  }) async {
    value = value.copyWith(exposure: exposure, contrast: contrast);

    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source: 'updateSceneProcessing(${value.exposure}, ${value.contrast})',
    );
  }

  /// Wendet einen Material-/Schattierungsmodus auf ausgewählte oder nicht ausgewählte Teile an.
  ///
  /// [mode]: Anzuwendender Schattierungsmodus (wireframe, xray usw.).
  /// [applyToSelected]: Wenn true, auf ausgewählte Teile; wenn false, auf nicht ausgewählte.
  Future<void> applyMaterialModeToSelection(
    ShadingMode mode, {
    bool applyToSelected = true,
  }) async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source: 'applyMaterialModeToSelection("${mode.name}", $applyToSelected)',
    );
  }
}
