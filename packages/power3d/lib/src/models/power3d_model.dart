import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Quelle des 3D-Modells.
enum Power3DSource {
  /// Aus Flutter-Assets geladen.
  asset,

  /// Von einer Netzwerk-URL geladen.
  network,

  /// Von einem lokalen Dateipfad geladen.
  file,
}

/// Richtungen für die automatische Rotation des Modells.
enum RotationDirection {
  /// Rotation im Uhrzeigersinn.
  clockwise,

  /// Rotation gegen den Uhrzeigersinn.
  counterClockwise,
}

/// In der Szene unterstützte Lichttypen.
enum LightType {
  /// Umgebungslicht, das alle Objekte gleichmäßig aus einer bestimmten Richtung beleuchtet.
  hemispheric,

  /// Parallele Lichtstrahlen (wie Sonnenlicht).
  directional,

  /// Licht, das von einem Punkt in alle Richtungen strahlt.
  point,
}

/// Schattierungs- und Rendermodi für die 3D-Szene.
enum ShadingMode {
  /// Standard-Schattierung mit Beleuchtung.
  shaded,

  /// Underlyinges Mesh-Wireframe anzeigen.
  wireframe,

  /// Nur die Vertices des Meshes rendern.
  pointCloud,

  /// Halbtransparentes Röntgen-Rendering.
  xray,

  /// Flache Farben ohne Beleuchtung rendern.
  unlit,

  /// Oberflächennormalen visualisieren.
  normals,

  /// UV-Checkerboard-Muster zur Textur-Ausrichtung anzeigen.
  uvChecker,

  /// Roughness-Eigenschaft der Materialien visualisieren.
  roughness,

  /// Metallic-Eigenschaft der Materialien visualisieren.
  metallic,
}

/// Konfiguration zum Überschreiben von Materialeigenschaften des Modells.
class MaterialConfig {
  /// Basisfarbe des Materials.
  final Color? color;

  /// Metallic-Eigenschaft (0.0 bis 1.0).
  final double? metallic;

  /// Roughness-Eigenschaft (0.0 bis 1.0).
  final double? roughness;

  /// Transparenzstufe (0.0 bis 1.0).
  final double? alpha;

  /// Emissive (leuchtende) Farbe des Materials.
  final Color? emissiveColor;

  /// Ob beide Seiten der Mesh-Polygone gerendert werden.
  final bool? doubleSided;

  /// Erstellt eine neue Materialkonfiguration.
  const MaterialConfig({
    this.color,
    this.metallic,
    this.roughness,
    this.alpha,
    this.emissiveColor,
    this.doubleSided,
  });

  /// Erstellt eine Kopie dieser Konfiguration mit ersetzten Feldern.
  MaterialConfig copyWith({
    Color? color,
    double? metallic,
    double? roughness,
    double? alpha,
    Color? emissiveColor,
    bool? doubleSided,
  }) {
    return MaterialConfig(
      color: color ?? this.color,
      metallic: metallic ?? this.metallic,
      roughness: roughness ?? this.roughness,
      alpha: alpha ?? this.alpha,
      emissiveColor: emissiveColor ?? this.emissiveColor,
      doubleSided: doubleSided ?? this.doubleSided,
    );
  }
}

/// Visueller Stil für ausgewählte oder nicht ausgewählte Teile des Modells.
class SelectionStyle {
  /// Farbe zur Hervorhebung des ausgewählten Teils.
  final Color? highlightColor;

  /// Farbe der Kontur um das ausgewählte Teil.
  final Color? outlineColor;

  /// Breite der Kontur.
  final double? outlineWidth;

  /// Erstellt einen neuen Selection-Stil.
  const SelectionStyle({
    this.highlightColor,
    this.outlineColor,
    this.outlineWidth,
  });

  /// Erstellt eine Kopie dieses Stils mit ersetzten Feldern.
  SelectionStyle copyWith({
    Color? highlightColor,
    Color? outlineColor,
    double? outlineWidth,
  }) {
    return SelectionStyle(
      highlightColor: highlightColor ?? this.highlightColor,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
    );
  }
}

/// Positionsversatz für ausgewählte Teile.
class SelectionShift {
  /// Versatz auf der X-Achse.
  final double x;

  /// Versatz auf der Y-Achse.
  final double y;

  /// Versatz auf der Z-Achse.
  final double z;

  /// Erstellt einen neuen Selection-Shift.
  const SelectionShift({this.x = 0, this.y = 0, this.z = 0});

  /// Erstellt eine Kopie dieses Shifts mit ersetzten Feldern.
  SelectionShift copyWith({double? x, double? y, double? z}) {
    return SelectionShift(x: x ?? this.x, y: y ?? this.y, z: z ?? this.z);
  }
}

/// Konfiguration für das Objektteil-Auswahl-System.
class SelectionConfig {
  /// Ob die Auswahl aktiviert ist.
  final bool enabled;

  /// Ob mehrere Teile gleichzeitig ausgewählt werden können.
  final bool multipleSelection;

  /// Stil für ausgewählte Teile.
  final SelectionStyle? selectionStyle;

  /// Stil für Teile, die NICHT ausgewählt sind.
  final SelectionStyle? unselectedStyle;

  /// Skalierungsfaktor für ausgewählte Teile.
  final double scaleSelection;

  /// Positionsversatz für ausgewählte Teile.
  final SelectionShift? selectionShift;

  /// Erstellt eine neue Selection-Konfiguration.
  const SelectionConfig({
    this.enabled = false,
    this.multipleSelection = false,
    this.selectionStyle,
    this.unselectedStyle,
    this.scaleSelection = 1.0,
    this.selectionShift,
  });

  /// Erstellt eine Kopie dieser Konfiguration mit ersetzten Feldern.
  SelectionConfig copyWith({
    bool? enabled,
    bool? multipleSelection,
    SelectionStyle? selectionStyle,
    SelectionStyle? unselectedStyle,
    double? scaleSelection,
    SelectionShift? selectionShift,
  }) {
    return SelectionConfig(
      enabled: enabled ?? this.enabled,
      multipleSelection: multipleSelection ?? this.multipleSelection,
      selectionStyle: selectionStyle ?? this.selectionStyle,
      unselectedStyle: unselectedStyle ?? this.unselectedStyle,
      scaleSelection: scaleSelection ?? this.scaleSelection,
      selectionShift: selectionShift ?? this.selectionShift,
    );
  }
}

/// Stile für die Bounding-Box-Visualisierung.
enum BoundingBoxStyle {
  /// Standard-Wireframe-Würfel mit Scale-Handles.
  cube,

  /// Wireframe-Kugel um die Bounds.
  sphere,

  /// Einfache Wireframe-Box ohne Handles.
  simple,
}

/// Konfiguration für die Bounding-Box-Visualisierung.
class BoundingBoxConfig {
  /// Farbe der Bounding-Box-Linien.
  final Color color;

  /// Breite der Bounding-Box-Linien.
  final double lineWidth;

  /// Visueller Stil der Bounding Box.
  final BoundingBoxStyle style;

  /// Ob Abmessungen/Maße angezeigt werden.
  final bool showDimensions;

  /// Erstellt eine neue Bounding-Box-Konfiguration.
  const BoundingBoxConfig({
    this.color = Colors.green,
    this.lineWidth = 1.0,
    this.style = BoundingBoxStyle.cube,
    this.showDimensions = false,
  });

  /// Erstellt eine Kopie dieser Konfiguration mit ersetzten Feldern.
  BoundingBoxConfig copyWith({
    Color? color,
    double? lineWidth,
    BoundingBoxStyle? style,
    bool? showDimensions,
  }) {
    return BoundingBoxConfig(
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      style: style ?? this.style,
      showDimensions: showDimensions ?? this.showDimensions,
    );
  }
}

/// Datenstruktur für eine 3D-Modellquelle.
class Power3DData {
  /// Pfad oder URL zur Modelldatei.
  final String path;

  /// Quelltyp (Asset, Netzwerk oder Datei).
  final Power3DSource source;

  /// Benutzerdefinierter Dateiname (optional).
  final String? fileName;

  /// Erstellt eine neue Modell-Datenstruktur.
  const Power3DData({
    required this.path,
    required this.source,
    this.fileName,
  });

  /// Gibt die Dateiendung des Modellpfads zurück.
  String get extension => path.split('.').last.toLowerCase();
}

/// Ladestatus des 3D-Modells.
enum Power3DStatus {
  /// Initialzustand, kein Modellladen gestartet.
  initial,

  /// Modell wird gerade heruntergeladen oder in die Szene geladen.
  loading,

  /// Modell wurde erfolgreich geladen.
  loaded,

  /// Beim Laden ist ein Fehler aufgetreten.
  error,
}

/// Zustand des Power3D-Viewers.
class Power3DState {
  /// Aktueller Ladestatus.
  final Power3DStatus status;

  /// Fehlermeldung, wenn der Status [Power3DStatus.error] ist.
  final String? errorMessage;

  /// Name des aktuell geladenen Modells.
  final String? currentModelName;

  /// Ob die Babylon.js-Engine initialisiert ist.
  final bool isInitialized;

  /// Ob die Kamera gerade automatisch rotiert.
  final bool autoRotate;

  /// Geschwindigkeit der Kamerarotation.
  final double rotationSpeed;

  /// Richtung der Kamerarotation.
  final RotationDirection rotationDirection;

  /// Zeit, nach der die Auto-Rotation automatisch stoppen soll.
  final Duration? rotationStopAfter;

  /// Ob Kamera-Zoom aktiviert ist.
  final bool enableZoom;

  /// Maximal erlaubter Zoom-Level.
  final double maxZoom;

  /// Minimal erlaubter Zoom-Level.
  final double minZoom;

  /// Steuert, wie empfindlich Pinch-to-Zoom und Mausrad-Zoom sind.
  ///
  /// Bereich: 0.0 (schnellste / empfindlichste) bis 1.0 (langsamste / unempfindlichste).
  /// Standard ist 0.5 (ausgewogen).
  final double zoomSensitivity;

  /// Ob die Kameraposition (Panning) gesperrt ist.
  final bool isPositionLocked;

  /// Horizontaler Winkel (Alpha) der Kamera in Radiant.
  final double cameraAlpha;

  /// Vertikaler Winkel (Beta) der Kamera in Radiant.
  final double cameraBeta;

  /// Distanz (Radius) der Kamera zum Ziel.
  final double cameraRadius;

  /// Base64-kodierter String des zuletzt aufgenommenen Screenshots.
  final String? lastScreenshot;

  /// Liste der aktuell aktiven Lichter in der Szene.
  final List<LightingConfig> lights;

  /// Exposure-Wert der Szene.
  final double exposure;

  /// Kontrastwert der Szene.
  final double contrast;

  /// Aktueller Schattierungsmodus.
  final ShadingMode shadingMode;

  /// Globaler Material-Override für das gesamte Modell.
  final MaterialConfig? globalMaterial;

  /// Konfiguration des Auswahl-Systems.
  final SelectionConfig selectionConfig;

  /// Liste der Namen aktuell ausgewählter Teile.
  final List<String> selectedParts;

  /// Liste der Namen aller auswählbaren Teile im Modell.
  final List<String> availableParts;

  /// Liste der verfügbaren Animationen im Modell.
  final List<Power3DAnimation> animations;

  /// Ob mehrere Animationen gleichzeitig abgespielt werden können.
  final bool playMultiple;

  /// Liste der Namen ausgeblendeter Teile.
  final List<String> hiddenParts;

  /// Liste der Namen von Teilen mit sichtbaren Bounding Boxes.
  /// Liste der aktuell angezeigten Bounding Boxes.
  final List<String> boundingBoxParts;

  /// Hierarchische Struktur der Teile (JSON-Liste von Knoten).
  final List<dynamic>? partsHierarchy;

  /// Liste der verfügbaren Texturen in der Szene.
  final List<Power3DTexture> textures;

  /// JSON-String mit den Annotationen.
  final String? annotations;

  /// Zu verwendender Annotationsstil. Kann ein vordefiniertes Enum oder ein eigener JS-String sein.
  final dynamic annotationStyle;


  /// Erstellt einen neuen [Power3DState].
  const Power3DState({
    this.isInitialized = false,
    this.status = Power3DStatus.initial,
    this.errorMessage,
    this.currentModelName,
    this.shadingMode = ShadingMode.shaded,
    this.globalMaterial,
    this.lights = const [],
    this.exposure = 1.0,
    this.contrast = 1.0,
    this.autoRotate = false,
    this.rotationSpeed = 1.0,
    this.rotationDirection = RotationDirection.counterClockwise,
    this.rotationStopAfter,
    this.isPositionLocked = false,
    this.enableZoom = true,
    this.minZoom = 0.5,
    this.maxZoom = 20.0,
    this.zoomSensitivity = 0.5,
    this.cameraAlpha = -1.57,
    this.cameraBeta = 1.25,
    this.cameraRadius = 3.0,
    this.lastScreenshot,
    this.selectionConfig = const SelectionConfig(),
    this.selectedParts = const [],
    this.availableParts = const [],
    this.animations = const [],
    this.playMultiple = false,
    this.partsHierarchy,
    this.hiddenParts = const [],
    this.boundingBoxParts = const [],
    this.textures = const [],
    this.annotations,
    this.annotationStyle,
  });

  /// Repräsentation des Initialzustands.
  factory Power3DState.initial() => const Power3DState();

  /// Erstellt eine Kopie dieses Zustands mit ersetzten Feldern.
  Power3DState copyWith({
    Power3DStatus? status,
    String? errorMessage,
    String? currentModelName,
    bool? isInitialized,
    bool? autoRotate,
    double? rotationSpeed,
    RotationDirection? rotationDirection,
    Duration? rotationStopAfter,
    bool? enableZoom,
    double? maxZoom,
    double? minZoom,
    double? zoomSensitivity,
    bool? isPositionLocked,
    double? cameraAlpha,
    double? cameraBeta,
    double? cameraRadius,
    String? lastScreenshot,
    List<LightingConfig>? lights,
    double? exposure,
    double? contrast,
    ShadingMode? shadingMode,
    MaterialConfig? globalMaterial,
    SelectionConfig? selectionConfig,
    List<String>? selectedParts,
    List<String>? availableParts,
    List<Power3DAnimation>? animations,
    bool? playMultiple,
    List<String>? hiddenParts,
    List<String>? boundingBoxParts,
    List<dynamic>? partsHierarchy,
    List<Power3DTexture>? textures,
    String? annotations,
    dynamic annotationStyle,
  }) {
    return Power3DState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentModelName: currentModelName ?? this.currentModelName,
      isInitialized: isInitialized ?? this.isInitialized,
      autoRotate: autoRotate ?? this.autoRotate,
      rotationSpeed: rotationSpeed ?? this.rotationSpeed,
      rotationDirection: rotationDirection ?? this.rotationDirection,
      rotationStopAfter: rotationStopAfter ?? this.rotationStopAfter,
      enableZoom: enableZoom ?? this.enableZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      minZoom: minZoom ?? this.minZoom,
      zoomSensitivity: zoomSensitivity ?? this.zoomSensitivity,
      isPositionLocked: isPositionLocked ?? this.isPositionLocked,
      cameraAlpha: cameraAlpha ?? this.cameraAlpha,
      cameraBeta: cameraBeta ?? this.cameraBeta,
      cameraRadius: cameraRadius ?? this.cameraRadius,
      lastScreenshot: lastScreenshot ?? this.lastScreenshot,
      lights: lights ?? this.lights,
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      shadingMode: shadingMode ?? this.shadingMode,
      globalMaterial: globalMaterial ?? this.globalMaterial,
      selectionConfig: selectionConfig ?? this.selectionConfig,
      selectedParts: selectedParts ?? this.selectedParts,
      availableParts: availableParts ?? this.availableParts,
      animations: animations ?? this.animations,
      playMultiple: playMultiple ?? this.playMultiple,
      hiddenParts: hiddenParts ?? this.hiddenParts,
      boundingBoxParts: boundingBoxParts ?? this.boundingBoxParts,
      partsHierarchy: partsHierarchy ?? this.partsHierarchy,
      textures: textures ?? this.textures,
      annotations: annotations ?? this.annotations,
      annotationStyle: annotationStyle ?? this.annotationStyle,
    );
  }
}

/// Metadaten einer Textur in der 3D-Szene.
class Power3DTexture {
  /// Eindeutige Kennung der Textur.
  final String uniqueId;

  /// Name der Textur oder Dateiname.
  final String name;

  /// Klassenname der Textur in Babylon.js.
  final String className;

  /// Ob dies eine Render-Target-Textur ist.
  final bool isRenderTarget;

  /// Helligkeits-/Intensitätsstufe der Textur.
  final double level;

  /// URL der Textur, falls vorhanden.
  final String? url;

  /// Horizontale Skalierung/Kachelung.
  final double uScale;

  /// Vertikale Skalierung/Kachelung.
  final double vScale;

  /// Horizontaler Versatz.
  final double uOffset;

  /// Vertikaler Versatz.
  final double vOffset;

  /// Erstellt ein neues Textur-Metadaten-Objekt.
  const Power3DTexture({
    required this.uniqueId,
    required this.name,
    required this.className,
    this.isRenderTarget = false,
    this.level = 1.0,
    this.url,
    this.uScale = 1.0,
    this.vScale = 1.0,
    this.uOffset = 0.0,
    this.vOffset = 0.0,
  });

  /// Erstellt eine [Power3DTexture] aus einer JSON-Map.
  factory Power3DTexture.fromJson(Map<String, dynamic> json) {
    return Power3DTexture(
      uniqueId: json['uniqueId'] ?? '',
      name: json['name'] ?? '',
      className: json['className'] ?? '',
      isRenderTarget: json['isRenderTarget'] ?? false,
      level: (json['level'] as num?)?.toDouble() ?? 1.0,
      url: json['url'],
      uScale: (json['uScale'] as num?)?.toDouble() ?? 1.0,
      vScale: (json['vScale'] as num?)?.toDouble() ?? 1.0,
      uOffset: (json['uOffset'] as num?)?.toDouble() ?? 0.0,
      vOffset: (json['vOffset'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Anfrageobjekt zum Aktualisieren von Textureigenschaften.
class TextureUpdate {
  /// Optionale Helligkeits-/Intensitätsstufe.
  final double? level;

  /// Optionale horizontale Skalierung.
  final double? uScale;

  /// Optionale vertikale Skalierung.
  final double? vScale;

  /// Optionaler horizontaler Versatz.
  final double? uOffset;

  /// Optionaler vertikaler Versatz.
  final double? vOffset;

  /// Erstellt eine Textur-Update-Anfrage.
  const TextureUpdate({
    this.level,
    this.uScale,
    this.vScale,
    this.uOffset,
    this.vOffset,
  });

  /// Wandelt das Update in eine JSON-Map um.
  Map<String, dynamic> toJson() {
    return {
      if (level != null) 'level': level,
      if (uScale != null) 'uScale': uScale,
      if (vScale != null) 'vScale': vScale,
      if (uOffset != null) 'uOffset': uOffset,
      if (vOffset != null) 'vOffset': vOffset,
    };
  }
}

/// Konfiguration für eine Lichtquelle in der Szene.
class LightingConfig {
  /// Lichttyp.
  final LightType type;

  /// Intensität des Lichts (üblicherweise 0.0 bis 1.0+).
  final double intensity;

  /// Farbe des Lichts.
  final Color color;

  /// Richtung des Lichts (für [LightType.directional]).
  final math.Point<double>? direction;

  /// Ob dieses Licht Schatten wirft.
  final bool castShadows;

  /// Unschärfegrad der Schatten.
  final double shadowBlur;

  /// Erstellt eine neue Beleuchtungskonfiguration.
  const LightingConfig({
    this.type = LightType.hemispheric,
    this.intensity = 0.7,
    this.color = Colors.white,
    this.direction,
    this.castShadows = false,
    this.shadowBlur = 10.0,
  });

  /// Erstellt eine Kopie dieser Beleuchtungskonfiguration mit ersetzten Feldern.
  LightingConfig copyWith({
    LightType? type,
    double? intensity,
    Color? color,
    math.Point<double>? direction,
    bool? castShadows,
    double? shadowBlur,
  }) {
    return LightingConfig(
      type: type ?? this.type,
      intensity: intensity ?? this.intensity,
      color: color ?? this.color,
      direction: direction ?? this.direction,
      castShadows: castShadows ?? this.castShadows,
      shadowBlur: shadowBlur ?? this.shadowBlur,
    );
  }
}

/// Repräsentiert den Zustand einer Animation im 3D-Modell.
class Power3DAnimation {
  /// Name der Animation.
  final String name;

  /// Ob die Animation gerade abgespielt wird.
  final bool isPlaying;

  /// Aktuelle Wiedergabegeschwindigkeit.
  final double speed;

  /// Ob die Animation in einer Schleife läuft.
  final bool loop;

  /// Erstellt ein neues Animationszustands-Objekt.
  const Power3DAnimation({
    required this.name,
    this.isPlaying = false,
    this.speed = 1.0,
    this.loop = true,
  });

  /// Erstellt eine [Power3DAnimation] aus einer JSON-Map.
  factory Power3DAnimation.fromJson(Map<String, dynamic> json) {
    return Power3DAnimation(
      name: json['name'] ?? '',
      isPlaying: json['isPlaying'] ?? false,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      loop: json['loop'] ?? true,
    );
  }

  /// Erstellt eine Kopie dieses Animationszustands mit ersetzten Feldern.
  Power3DAnimation copyWith({
    String? name,
    bool? isPlaying,
    double? speed,
    bool? loop,
  }) {
    return Power3DAnimation(
      name: name ?? this.name,
      isPlaying: isPlaying ?? this.isPlaying,
      speed: speed ?? this.speed,
      loop: loop ?? this.loop,
    );
  }
}
