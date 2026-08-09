part of 'power3d_controller.dart';

extension AnnotationExtension on Power3DController {
  /// Setzt den JSON-String mit den Annotationen.
  void setAnnotations(String json) {
    debugPrint('Power3D: setAnnotations called (length: ${json.length})');
    value = value.copyWith(annotations: json);

    if (value.isInitialized) {
      unawaited(
        _webViewController?.evaluateJavascript(
          source: 'setAnnotations(JSON.parse(${jsonEncode(json)}))',
        ),
      );
    }
  }

  /// Setzt den Annotationsstil.
  ///
  /// [style] kann sein:
  /// - Ein roher HTML/CSS/JS-String zum Injizieren.
  /// - Ein Pfad zu einer lokalen JavaScript-Stil-Datei.
  /// - Ein eigener Typ (z. B. Enum), der vom Hook `onResolveStyle` behandelt wird.
  void setAnnotationStyle(dynamic style, {bool force = false}) {
    final bool changed = value.annotationStyle != style;
    if (changed) {
      value = value.copyWith(annotationStyle: style);
    }

    if (style is String) {
      if (value.isInitialized && (changed || force)) {
        unawaited(
          _webViewController?.evaluateJavascript(
            source: 'setAnnotationStyle(`${style.replaceAll('`', '\\`')}`)',
          ),
        );
      }
    } else {
      // Das Bereitstellen von Stil-Dateien erfordert bereite Engine-Assets.
      // Wenn noch nicht initialisiert, behalten wir den Stil nur im State.
      // Die Methode initialize() ruft dies erneut auf, sobald bereit.
      if (!value.isInitialized && !force) return;

      // Wahrscheinlich ein Enum oder eigenes Style-Objekt. Zuerst lokalen Hook, dann global prüfen.
      if (onResolveStyle != null) {
        unawaited(onResolveStyle!(style));
      } else if (Power3DController.globalStyleResolver != null) {
        unawaited(Power3DController.globalStyleResolver!(this, style));
      } else {
        debugPrint(
          'Power3D: Warning - annotationStyle is not a String and no resolver found. Is power3d_annotations plugin registered?',
        );
      }
    }
  }

  /// Schaltet die Sichtbarkeit aller Annotationen um.
  void toggleAnnotations(bool visible) {
    if (value.isInitialized) {
      unawaited(
        _webViewController?.evaluateJavascript(
          source: 'setAnnotationsVisible($visible)',
        ),
      );
    }
  }

  /// Bewegt die Kamera sanft zu einer bestimmten Orbit- und Zielposition.
  /// 
  /// [orbit]: Liste der Kamerawinkel [Alpha, Beta, Radius].
  /// [target]: Liste der Weltkoordinaten [X, Y, Z].
  /// [duration]: Dauer der Flug-Übergangsanimation in Sekunden.
  void focusCamera({
    required List<double> orbit,
    required List<double> target,
    double duration = 0.5,
  }) {
    if (value.isInitialized) {
      unawaited(
        _webViewController?.evaluateJavascript(
          source:
              'transitionCamera(${orbit[0]}, ${orbit[1]}, ${orbit[2]}, {x: ${target[0]}, y: ${target[1]}, z: ${target[2]}}, ${duration * 1000})',
        ),
      );
    }
  }
}
