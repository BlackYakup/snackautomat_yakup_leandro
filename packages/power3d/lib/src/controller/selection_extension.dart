part of 'power3d_controller.dart';

/// Selection- und Hierarchy-Erweiterung für [Power3DController].
extension SelectionExtension on Power3DController {
  /// Registriert einen Callback für Teil-Auswahl-Ereignisse.
  ///
  /// Der Callback wird ausgelöst, wenn ein Teil ausgewählt oder abgewählt wird.
  void onPartSelected(Function(String partName, bool selected) callback) {
    _onPartSelectedCallback = callback;
  }

  /// Ruft die Liste der verfügbaren Mesh-Teilnamen aus dem aktuell geladenen Modell ab.
  Future<List<String>> getPartsList() async {
    if (_webViewController == null) return [];

    if (value.availableParts.isNotEmpty) {
      return value.availableParts;
    }

    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'JSON.stringify(getPartsList())',
      );

      final parts = _parseJsStringList(result?.toString() ?? '');
      if (parts.isNotEmpty) {
        value = value.copyWith(availableParts: parts);
      }
      return parts;
    } catch (e) {
      debugPrint('Failed to get parts list: $e');
      return value.availableParts;
    }
  }

  List<String> _parseJsStringList(String raw) {
    var resultString = raw.trim();

    if (resultString == 'null' || resultString.isEmpty) {
      return const [];
    }

    if (resultString.startsWith('"') && resultString.endsWith('"')) {
      try {
        resultString = jsonDecode(resultString) as String;
      } catch (_) {
        resultString = resultString
            .substring(1, resultString.length - 1)
            .replaceAll(r'\"', '"');
      }
    }

    try {
      final decoded = jsonDecode(resultString);
      if (decoded is List) {
        return decoded.map((entry) => entry.toString()).toList();
      }
    } catch (_) {
      // z. B. [Chips] ohne Anführungszeichen von der WebView
    }

    final match = RegExp(r'^\s*\[(.*)\]\s*$').firstMatch(resultString);
    if (match == null) {
      return const [];
    }

    final inner = match.group(1)!.trim();
    if (inner.isEmpty) {
      return const [];
    }

    return inner
        .split(',')
        .map((part) {
          var value = part.trim();
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.substring(1, value.length - 1);
          }
          return value;
        })
        .where((part) => part.isNotEmpty)
        .toList();
  }

  /// Fokussiert und wählt ein bestimmtes Teil anhand seines Mesh-[partName] aus.
  Future<void> selectPart(String partName) async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source: 'selectPart("$partName")',
    );

    final newSelected = List<String>.from(value.selectedParts);
    if (!newSelected.contains(partName)) {
      if (!value.selectionConfig.multipleSelection) {
        newSelected.clear();
      }
      newSelected.add(partName);
      value = value.copyWith(selectedParts: newSelected);
    }
  }

  /// Hebt die Auswahl eines bestimmten Teils anhand seines Mesh-[partName] auf.
  Future<void> unselectPart(String partName) async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source: 'unselectPart("$partName")',
    );

    final newSelected = List<String>.from(value.selectedParts);
    newSelected.remove(partName);
    value = value.copyWith(selectedParts: newSelected);
  }

  /// Löscht alle aktuell ausgewählten Modellteile.
  Future<void> clearSelection() async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(source: 'clearSelection()');
    value = value.copyWith(selectedParts: []);
  }

  /// Aktualisiert die globale Selection-Konfiguration inkl. Stile und Verhalten.
  Future<void> updateSelectionConfig(SelectionConfig config) async {
    value = value.copyWith(selectionConfig: config);

    if (_webViewController == null) return;

    final Map<String, dynamic> jsConfig = {
      'enabled': config.enabled,
      'multipleSelection': config.multipleSelection,
      'scaleSelection': config.scaleSelection,
      'selectionShift': {
        'x': config.selectionShift?.x ?? 0,
        'y': config.selectionShift?.y ?? 0,
        'z': config.selectionShift?.z ?? 0,
      },
    };

    if (config.selectionStyle != null) {
      jsConfig['selectionStyle'] = {
        if (config.selectionStyle!.highlightColor != null)
          'highlightColor':
              '#${config.selectionStyle!.highlightColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        if (config.selectionStyle!.outlineColor != null)
          'outlineColor':
              '#${config.selectionStyle!.outlineColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        if (config.selectionStyle!.outlineWidth != null)
          'outlineWidth': config.selectionStyle!.outlineWidth,
      };
    }

    if (config.unselectedStyle != null) {
      jsConfig['unselectedStyle'] = {
        if (config.unselectedStyle!.highlightColor != null)
          'highlightColor':
              '#${config.unselectedStyle!.highlightColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        if (config.unselectedStyle!.outlineColor != null)
          'outlineColor':
              '#${config.unselectedStyle!.outlineColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        if (config.unselectedStyle!.outlineWidth != null)
          'outlineWidth': config.unselectedStyle!.outlineWidth,
      };
    }

    await _webViewController!.evaluateJavascript(
      source: 'enableSelectionMode(${jsonEncode(jsConfig)})',
    );
  }

  // ===== Hierarchie & Node-Extras =====

  /// Ruft die hierarchische Struktur der Teile im Modell ab.
  ///
  /// [useCategorization]: Wenn true, werden Namenskonventionen wie „Category.PartName“ verwendet.
  /// Wenn false (Standard), werden die Parent-Child-Beziehungen des GLTF-Szenengraphen genutzt.
  Future<List<dynamic>> getPartsHierarchy({
    bool useCategorization = false,
  }) async {
    if (_webViewController == null) return [];

    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'JSON.stringify(getPartsHierarchy($useCategorization))',
      );

      String resultString = result.toString();
      // WebView-Ergebnisse sind oft in zusätzliche Anführungszeichen gepackt und escaped
      if (resultString.startsWith('"') && resultString.endsWith('"')) {
        try {
          // Äußeren String-Wrapper dekodieren
          final decoded = jsonDecode(resultString);
          resultString = decoded.toString();
        } catch (e) {
          // Bei Fehlschlag führende/trailing Anführungszeichen entfernen, falls vorhanden
          resultString = resultString
              .substring(1, resultString.length - 1)
              .replaceAll('\\"', '"');
        }
      }

      if (resultString == 'null' || resultString.isEmpty) return [];

      final hierarchy = jsonDecode(resultString) as List<dynamic>;
      value = value.copyWith(partsHierarchy: hierarchy);
      return hierarchy;
    } catch (e) {
      debugPrint('Failed to get parts hierarchy: $e');
      return [];
    }
  }

  /// Holt Extras-Daten eines bestimmten Knotens/Teils (Label, Beschreibung, Kategorie usw.).
  ///
  /// Gibt eine Map mit Metadaten und GLTF-Extras zurück, falls vorhanden.
  Future<Map<String, dynamic>> getNodeExtras(String partName) async {
    if (_webViewController == null) return {};

    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'JSON.stringify(getNodeExtras("$partName"))',
      );

      String resultString = result.toString();
      if (resultString.startsWith('"') && resultString.endsWith('"')) {
        try {
          final decoded = jsonDecode(resultString);
          resultString = decoded.toString();
        } catch (e) {
          resultString = resultString
              .substring(1, resultString.length - 1)
              .replaceAll('\\"', '"');
        }
      }

      if (resultString == 'null' || resultString.isEmpty) return {};

      return jsonDecode(resultString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to get node extras: $e');
      return {};
    }
  }

  // ===== Sichtbarkeitssteuerung =====

  /// Blendet die angegebenen Teile aus.
  Future<void> hideParts(List<String> partNames) async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source: 'hideParts(${jsonEncode(partNames)})',
    );

    final newHidden = List<String>.from(value.hiddenParts);
    for (final name in partNames) {
      if (!newHidden.contains(name)) newHidden.add(name);
    }
    value = value.copyWith(hiddenParts: newHidden);
  }

  /// Zeigt die angegebenen Teile an (macht sie sichtbar).
  Future<void> showParts(List<String> showPartNames) async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source: 'showParts(${jsonEncode(showPartNames)})',
    );

    final newHidden = List<String>.from(value.hiddenParts);
    newHidden.removeWhere((name) => showPartNames.contains(name));
    value = value.copyWith(hiddenParts: newHidden);
  }

  /// Blendet alle aktuell ausgewählten Teile aus.
  Future<void> hideSelected() async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(source: 'hideSelected()');

    final newHidden = List<String>.from(value.hiddenParts);
    for (final name in value.selectedParts) {
      if (!newHidden.contains(name)) newHidden.add(name);
    }
    value = value.copyWith(hiddenParts: newHidden);
  }

  /// Blendet alle Teile außer den aktuell ausgewählten aus.
  Future<void> hideUnselected() async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(source: 'hideUnselected()');

    final unselected = value.availableParts
        .where((name) => !value.selectedParts.contains(name))
        .toList();
    value = value.copyWith(hiddenParts: unselected);
  }

  /// Zeigt alle Teile an (blendet alles wieder ein).
  Future<void> unhideAll() async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(source: 'unhideAll()');
    value = value.copyWith(hiddenParts: []);
  }

  // ===== Bounding-Box-Visualisierung =====

  /// Zeigt Bounding Boxes um die angegebenen Teile.
  ///
  /// [partNames]: Liste der Teilnamen, für die Bounding Boxes angezeigt werden.
  /// [config]: Optionale Konfiguration für das Aussehen (Farbe, Linienbreite usw.).
  Future<void> showBoundingBox(
    List<String> partNames, {
    BoundingBoxConfig? config,
  }) async {
    if (_webViewController == null) return;

    config ??= const BoundingBoxConfig();

    final String colorHex =
        '#${config.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

    final Map<String, dynamic> jsConfig = {
      'color': colorHex,
      'lineWidth': config.lineWidth,
      'style': config.style.name,
    };

    await _webViewController!.evaluateJavascript(
      source:
          'showBoundingBox(${jsonEncode(partNames)}, ${jsonEncode(jsConfig)})',
    );

    final newBoxes = List<String>.from(value.boundingBoxParts);
    for (final name in partNames) {
      if (!newBoxes.contains(name)) newBoxes.add(name);
    }
    value = value.copyWith(boundingBoxParts: newBoxes);
  }

  /// Blendet Bounding Boxes für die angegebenen Teile aus.
  Future<void> hideBoundingBox(List<String> partNames) async {
    if (_webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source: 'hideBoundingBox(${jsonEncode(partNames)})',
    );

    final newBoxes = List<String>.from(value.boundingBoxParts);
    newBoxes.removeWhere((name) => partNames.contains(name));
    value = value.copyWith(boundingBoxParts: newBoxes);
  }
}
