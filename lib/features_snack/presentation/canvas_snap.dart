part of 'slide_editor_library.dart';

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
    final stroke = Paint()
      ..color = PresentationTheme.accent
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(r, fill);
    canvas.drawRect(r, stroke);
  }

  @override
  bool shouldRepaint(covariant _MarqueePainter oldDelegate) =>
      oldDelegate.rect != rect;
}

/// Rückwärtskompatibler Alias.
typedef SlideEditorLayer = SlideCanvas;
