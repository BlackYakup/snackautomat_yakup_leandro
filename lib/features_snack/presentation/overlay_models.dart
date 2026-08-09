import 'dart:math';

import 'package:flutter/material.dart' show Color;

/// Overlay-Elemente auf Folien (Text / Kasten / Bild).
enum OverlayKind { text, box, image }

class OverlayEl {
  OverlayEl({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.text,
    this.fontSize,
    this.lineHeight,
    this.color,
    this.bg,
    this.src,
    this.fit = 'cover',
    this.align = 'left',
    this.fontWeight = 5,
    this.fontFamily,
    this.radius,
    this.pad,
    this.borderColor,
    this.module,
    this.cropL = 0,
    this.cropT = 0,
    this.cropR = 0,
    this.cropB = 0,
    this.z = 10,
  });

  final String id;
  final OverlayKind kind;
  double x;
  double y;
  double w;
  double h;
  String? text;
  double? fontSize;
  /// Zeilenhöhe für Text (muss zu Messung/Materialize passen).
  double? lineHeight;
  String? color;
  String? bg;
  String? src;
  /// cover | contain | fill
  String fit;
  /// left | center | right
  String align;
  /// 0=w100 … 8=w900 (Flutter FontWeight.values Index)
  int fontWeight;
  /// z. B. Consolas für Code / Dateipfade
  String? fontFamily;
  /// Eckenradius; null = Default je nach Kind
  double? radius;
  /// Innenabstand; null = Default je nach Kind
  double? pad;
  /// Optionaler Rahmen (CSS-Farbe)
  String? borderColor;
  /// Feste Modul-Darstellung: hint | section_folder | section_book | badge | tag | code_panel | code_head | code_body
  String? module;
  /// Zuschnitt 0–0.45 je Seite.
  double cropL;
  double cropT;
  double cropR;
  double cropB;
  int z;

  OverlayEl copy() => OverlayEl(
        id: id,
        kind: kind,
        x: x,
        y: y,
        w: w,
        h: h,
        text: text,
        fontSize: fontSize,
        lineHeight: lineHeight,
        color: color,
        bg: bg,
        src: src,
        fit: fit,
        align: align,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        radius: radius,
        pad: pad,
        borderColor: borderColor,
        module: module,
        cropL: cropL,
        cropT: cropT,
        cropR: cropR,
        cropB: cropB,
        z: z,
      );

  OverlayEl cloneWithNewId() => OverlayEl(
        id: overlayUid(kind.name),
        kind: kind,
        x: min(80, x + 3),
        y: min(80, y + 3),
        w: w,
        h: h,
        text: text,
        fontSize: fontSize,
        lineHeight: lineHeight,
        color: color,
        bg: bg,
        src: src,
        fit: fit,
        align: align,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        radius: radius,
        pad: pad,
        borderColor: borderColor,
        module: module,
        cropL: cropL,
        cropT: cropT,
        cropR: cropR,
        cropB: cropB,
        z: z,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        if (text != null) 'text': text,
        if (fontSize != null) 'fontSize': fontSize,
        if (lineHeight != null) 'lineHeight': lineHeight,
        if (color != null) 'color': color,
        if (bg != null) 'bg': bg,
        if (src != null) 'src': src,
        'fit': fit,
        'align': align,
        'fontWeight': fontWeight,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (radius != null) 'radius': radius,
        if (pad != null) 'pad': pad,
        if (borderColor != null) 'borderColor': borderColor,
        if (module != null) 'module': module,
        'cropL': cropL,
        'cropT': cropT,
        'cropR': cropR,
        'cropB': cropB,
        'z': z,
      };

  factory OverlayEl.fromJson(Map<String, dynamic> json) {
    return OverlayEl(
      id: json['id'] as String? ?? overlayUid('el'),
      kind: OverlayKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => OverlayKind.text,
      ),
      x: (json['x'] as num?)?.toDouble() ?? 20,
      y: (json['y'] as num?)?.toDouble() ?? 20,
      w: (json['w'] as num?)?.toDouble() ?? 30,
      h: (json['h'] as num?)?.toDouble() ?? 12,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      lineHeight: (json['lineHeight'] as num?)?.toDouble(),
      color: json['color'] as String?,
      bg: json['bg'] as String?,
      src: json['src'] as String?,
      fit: json['fit'] as String? ?? 'cover',
      align: json['align'] as String? ?? 'left',
      fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 5,
      fontFamily: json['fontFamily'] as String?,
      radius: (json['radius'] as num?)?.toDouble(),
      pad: (json['pad'] as num?)?.toDouble(),
      borderColor: json['borderColor'] as String?,
      module: json['module'] as String?,
      cropL: (json['cropL'] as num?)?.toDouble() ?? 0,
      cropT: (json['cropT'] as num?)?.toDouble() ?? 0,
      cropR: (json['cropR'] as num?)?.toDouble() ?? 0,
      cropB: (json['cropB'] as num?)?.toDouble() ?? 0,
      z: (json['z'] as num?)?.toInt() ?? 10,
    );
  }
}

typedef OverlayDoc = Map<String, List<OverlayEl>>;

String overlayUid([String prefix = 'el']) {
  final r = Random().nextInt(1 << 32).toRadixString(36);
  return '${prefix}_$r';
}

OverlayEl createTextOverlay() => OverlayEl(
      id: overlayUid('txt'),
      kind: OverlayKind.text,
      x: 28,
      y: 35,
      w: 22,
      h: 5,
      text: 'Neuer Text',
      fontSize: 22,
      lineHeight: 1.25,
      color: '#1A1E24',
      bg: 'transparent',
    );

OverlayEl createBoxOverlay() => OverlayEl(
      id: overlayUid('box'),
      kind: OverlayKind.box,
      x: 30,
      y: 30,
      w: 35,
      h: 22,
      text: 'Notiz',
      fontSize: 16,
      color: '#E8EEF2',
      bg: 'rgba(18,26,32,0.88)',
      radius: 12,
      pad: 12,
    );

OverlayEl createImageOverlay(String src) => OverlayEl(
      id: overlayUid('img'),
      kind: OverlayKind.image,
      x: 25,
      y: 20,
      w: 45,
      h: 40,
      src: src,
      fit: 'cover',
    );

/// Hinweis-Kasten (wie Summary auf Code-Folien).
OverlayEl createHintModule({double x = 4, double y = 28}) => OverlayEl(
      id: overlayUid('hint'),
      kind: OverlayKind.box,
      x: x,
      y: y,
      w: 40,
      h: 10,
      text: 'Kurzer Hinweis — was hier passiert.',
      fontSize: 13.5,
      lineHeight: 1.35,
      color: '#1A2228',
      bg: 'rgba(31,143,132,0.10)',
      borderColor: 'rgba(31,143,132,0.35)',
      fontWeight: 6,
      radius: 12,
      pad: 12,
      module: 'hint',
    );

/// Abschnitts-Label (grün, klein).
OverlayEl createSectionModule({double x = 4, double y = 22}) => OverlayEl(
      id: overlayUid('sec'),
      kind: OverlayKind.text,
      x: x,
      y: y,
      w: 28,
      h: 3.5,
      text: 'Abschnitt',
      fontSize: 11,
      lineHeight: 1.0,
      color: '#1F8F84',
      fontWeight: 8,
      module: 'section_folder',
    );

/// Titel + Beschreibung als zwei Elemente.
List<OverlayEl> createTitleBodyModule({double x = 4, double y = 18}) => [
      OverlayEl(
        id: overlayUid('ttl'),
        kind: OverlayKind.text,
        x: x,
        y: y,
        w: 40,
        h: 5,
        text: 'Titel',
        fontSize: 22,
        lineHeight: 1.15,
        color: '#1A2228',
        fontWeight: 7,
      ),
      OverlayEl(
        id: overlayUid('body'),
        kind: OverlayKind.text,
        x: x,
        y: y + 6,
        w: 40,
        h: 8,
        text: 'Beschreibung in einfachen Worten.',
        fontSize: 13,
        lineHeight: 1.35,
        color: '#1A2228',
        fontWeight: 5,
      ),
    ];

/// Nummerierter Schritt: Badge + Text.
List<OverlayEl> createStepModule({
  int number = 1,
  double x = 4,
  double y = 40,
}) {
  return [
    OverlayEl(
      id: overlayUid('num'),
      kind: OverlayKind.box,
      x: x,
      y: y,
      w: 1.375,
      h: 2.45,
      text: '$number',
      fontSize: 11,
      color: '#FFFFFF',
      bg: '#1F8F84',
      align: 'center',
      fontWeight: 8,
      radius: 6,
      pad: 0,
      module: 'badge',
    ),
    OverlayEl(
      id: overlayUid('step'),
      kind: OverlayKind.text,
      x: x + 2.0,
      y: y,
      w: 36,
      h: 6,
      text: 'Schritt des Schritts…',
      fontSize: 13,
      lineHeight: 1.35,
      color: '#1A2228',
    ),
  ];
}

Color? parseCssColor(String? raw) {
  if (raw == null || raw.isEmpty || raw == 'transparent') return null;
  if (raw.startsWith('#') && (raw.length == 7 || raw.length == 9)) {
    final hex = raw.substring(1);
    final value = int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return Color(value);
  }
  final rgba = RegExp(
    r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)',
  ).firstMatch(raw);
  if (rgba != null) {
    final a = ((double.tryParse(rgba.group(4) ?? '1') ?? 1) * 255).round();
    return Color.fromARGB(
      a,
      int.parse(rgba.group(1)!),
      int.parse(rgba.group(2)!),
      int.parse(rgba.group(3)!),
    );
  }
  return null;
}
