part of 'slide_materialize_library.dart';


const _dw = PresentationTheme.slideDesignWidth;
const _dh = PresentationTheme.slideDesignHeight;

double _px(double pct, double total) => pct / 100 * total;
double _pctX(double px) => px / _dw * 100;
double _pctY(double px) => px / _dh * 100;

FontWeight _fw(int index) =>
    FontWeight.values[index.clamp(0, FontWeight.values.length - 1)];

/// Misst Text wie die Canvas-Darstellung.
Size measureOverlayText(
  String text, {
  required double fontSize,
  int fontWeight = 5,
  double height = 1.25,
  double letterSpacing = 0,
  double maxWidth = double.infinity,
  TextAlign align = TextAlign.left,
  String? fontFamily,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: _fw(fontWeight),
        height: height,
        letterSpacing: letterSpacing,
        fontFamily: fontFamily,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: maxWidth);
  return Size(
    math.max(1, painter.width),
    math.max(1, painter.height),
  );
}

/// Sicherheitszuschlag: TextPainter ist oft enger als das gerenderte Text-Widget.
double _textWidthPad(double fontSize) => math.max(14.0, fontSize * 0.4);

Size _contain(Size box, Size image) {
  if (image.width <= 0 || image.height <= 0) return box;
  final scale = math.min(box.width / image.width, box.height / image.height);
  return Size(image.width * scale, image.height * scale);
}

/// Bekannte Asset-Auflösungen (sonst 3:2).
Size imageAssetSize(String src) {
  if (src.contains('/diagrams/')) return const Size(1536, 1024);
  if (src.contains('facet-emblem')) return const Size(512, 512);
  if (src.contains('/status/')) return const Size(640, 400);
  return const Size(3, 2);
}

/// Passt nur die Höhe an die aktuelle Breite an — Breite bleibt unverändert
/// (manuelles Ziehen im Editor darf nicht überschrieben werden).
void fitTextBoxesToContent(List<OverlayEl> els) {
  for (final e in els) {
    if (e.kind != OverlayKind.text) continue;
    final raw = e.text ?? '';
    if (raw.isEmpty) continue;
    final fs = e.fontSize ?? 18;
    final lh = e.lineHeight ?? 1.25;
    final wrapped = measureOverlayText(
      raw,
      fontSize: fs,
      fontWeight: e.fontWeight,
      height: lh,
      maxWidth: _px(e.w, _dw),
      fontFamily: e.fontFamily,
    );
    e.h = _pctY(wrapped.height + 4).clamp(1.2, 40.0).toDouble();
  }
}

/// @Deprecated Alias — nutzt fitTextBoxesToContent.
void tightenOverlayTextHeights(List<OverlayEl> els) =>
    fitTextBoxesToContent(els);

/// Standard-Layout einer Folie als absolute Canvas-Elemente (%).
