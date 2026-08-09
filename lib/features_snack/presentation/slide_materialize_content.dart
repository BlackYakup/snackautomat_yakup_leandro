part of 'slide_materialize_library.dart';

/// Positionen folgen dem Abspiel-Layout (SlideView) auf 1600×900.
List<OverlayEl> materializeSlide(PresentationSlide slide) {
  var z = 1;

  OverlayEl text({
    required String id,
    required String value,
    required double x,
    required double y,
    required double w,
    required double h,
    double fontSize = 18,
    double? lineHeight,
    String color = '#1A2228',
    String align = 'left',
    int fontWeight = 5,
    String? fontFamily,
    String? module,
  }) {
    return OverlayEl(
      id: '${slide.id}_$id',
      kind: OverlayKind.text,
      x: x,
      y: y,
      w: w,
      h: h,
      text: value,
      fontSize: fontSize,
      lineHeight: lineHeight,
      color: color,
      bg: 'transparent',
      align: align,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      module: module,
      z: z++,
    );
  }

  OverlayEl image({
    required String id,
    required String src,
    required double x,
    required double y,
    required double w,
    required double h,
    String fit = 'fill',
  }) {
    return OverlayEl(
      id: '${slide.id}_$id',
      kind: OverlayKind.image,
      x: x,
      y: y,
      w: w,
      h: h,
      src: src,
      fit: fit,
      z: z++,
    );
  }

  OverlayEl box({
    required String id,
    required String value,
    required double x,
    required double y,
    required double w,
    required double h,
    double fontSize = 14,
    double? lineHeight,
    String color = '#1A2228',
    String bg = 'rgba(255,255,255,0.82)',
    String align = 'left',
    int fontWeight = 5,
    String? fontFamily,
    double? radius,
    double? pad,
    String? borderColor,
    String? module,
    String? src,
  }) {
    return OverlayEl(
      id: '${slide.id}_$id',
      kind: OverlayKind.box,
      x: x,
      y: y,
      w: w,
      h: h,
      text: value,
      fontSize: fontSize,
      lineHeight: lineHeight,
      color: color,
      bg: bg,
      src: src,
      align: align,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      radius: radius,
      pad: pad,
      borderColor: borderColor,
      module: module,
      z: z++,
    );
  }

  /// Text-Box: eine Zeile wenn möglich (mit Sicherheitsbreite), sonst Spaltenumbruch.
  OverlayEl layoutText({
    required String id,
    required String value,
    required double xPx,
    required double yPx,
    required double maxWidthPx,
    required double fontSize,
    String color = '#1A2228',
    String align = 'left',
    int fontWeight = 5,
    double height = 1.25,
    double letterSpacing = 0,
    bool tightWidth = true,
    String? fontFamily,
    String? module,
  }) {
    final alignEnum = align == 'center'
        ? TextAlign.center
        : align == 'right'
            ? TextAlign.right
            : TextAlign.left;

    final natural = measureOverlayText(
      value,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      maxWidth: double.infinity,
      align: alignEnum,
    );
    final pad = _textWidthPad(fontSize);
    final wantW = natural.width + pad;

    late final double boxW;
    late final double boxH;
    if (tightWidth && wantW <= maxWidthPx) {
      boxW = wantW.clamp(8.0, maxWidthPx);
      boxH = natural.height + 2;
    } else {
      boxW = maxWidthPx;
      final wrapped = measureOverlayText(
        value,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        maxWidth: boxW,
        align: alignEnum,
      );
      boxH = wrapped.height + 2;
    }

    var x = xPx;
    if (align == 'center') {
      x = xPx + (maxWidthPx - boxW) / 2;
    } else if (align == 'right') {
      x = xPx + (maxWidthPx - boxW);
    }

    return text(
      id: id,
      value: value,
      x: _pctX(x),
      y: _pctY(yPx),
      w: _pctX(boxW),
      h: _pctY(boxH),
      fontSize: fontSize,
      lineHeight: height,
      color: color,
      align: align,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      module: module,
    );
  }

  /// Bild bündig: Box = contain-Rechteck im Panel (kein Leerraum in der Auswahl).
  OverlayEl tightImage({
    required String id,
    required String src,
    required double panelX,
    required double panelY,
    required double panelW,
    required double panelH,
  }) {
    final fitted = _contain(Size(panelW, panelH), imageAssetSize(src));
    final x = panelX + (panelW - fitted.width) / 2;
    final y = panelY + (panelH - fitted.height) / 2;
    return image(
      id: id,
      src: src,
      x: _pctX(x),
      y: _pctY(y),
      w: _pctX(fitted.width),
      h: _pctY(fitted.height),
      fit: 'fill',
    );
  }

  switch (slide) {
    case TitleSlide s:
      // Wie _TitleSlideView: Block vertikal zentrieren (kein Hochrutschen).
      const maxW = 900.0;
      const left = (_dw - maxW) / 2;
      const gap1 = 28.0;
      const gap2 = 16.0;
      const gap3 = 28.0;
      const emblem = 88.0;

      final titleSize = measureOverlayText(
        s.title,
        fontSize: 48,
        fontWeight: 7,
        height: 1.1,
        maxWidth: maxW,
        align: TextAlign.center,
      );
      final subSize = measureOverlayText(
        s.subtitle,
        fontSize: 20,
        height: 1.35,
        maxWidth: maxW,
        align: TextAlign.center,
      );
      final metaSize = measureOverlayText(
        s.meta,
        fontSize: 14,
        fontWeight: 5,
        maxWidth: maxW,
        align: TextAlign.center,
      );
      final blockH = emblem +
          gap1 +
          titleSize.height +
          gap2 +
          subSize.height +
          gap3 +
          metaSize.height;
      var y = (_dh - blockH) / 2;

      final els = <OverlayEl>[
        image(
          id: 'emblem',
          src: 'assets/presentation/brand/facet-emblem.png',
          x: _pctX((_dw - emblem) / 2),
          y: _pctY(y),
          w: _pctX(emblem),
          h: _pctY(emblem),
          fit: 'contain',
        ),
      ];
      y += emblem + gap1;
      els.add(
        layoutText(
          id: 'title',
          value: s.title,
          xPx: left,
          yPx: y,
          maxWidthPx: maxW,
          fontSize: 48,
          align: 'center',
          fontWeight: 7,
          height: 1.1,
        ),
      );
      y += _px(els.last.h, _dh) + gap2;
      els.add(
        layoutText(
          id: 'sub',
          value: s.subtitle,
          xPx: left,
          yPx: y,
          maxWidthPx: maxW,
          fontSize: 20,
          color: '#5A6A75',
          align: 'center',
          height: 1.35,
        ),
      );
      y += _px(els.last.h, _dh) + gap3;
      els.add(
        layoutText(
          id: 'meta',
          value: s.meta,
          xPx: left,
          yPx: y,
          maxWidthPx: maxW,
          fontSize: 14,
          color: '#5A6A75',
          align: 'center',
        ),
      );
      return els;

    case ExplainSlide s:
      // Spiegelt _ExplainSlideView: Row flex 5|5, Paddings LTRB.
      final hasImg = s.imageAsset != null;
      final colW = hasImg ? _dw / 2 : _dw;
      const padL = 40.0;
      const padT = 36.0;
      const padR = 24.0;
      final contentX = padL;
      final contentMaxW = colW - padL - padR;

      final els = <OverlayEl>[];
      var y = padT;

      final kicker = layoutText(
        id: 'kicker',
        value: s.kicker.toUpperCase(),
        xPx: contentX,
        yPx: y,
        maxWidthPx: contentMaxW,
        fontSize: 12,
        color: '#1F8F84',
        fontWeight: 6,
        height: 1.0,
        letterSpacing: 1.2,
        tightWidth: true,
      );
      els.add(kicker);
      y += _px(kicker.h, _dh) + 12;

      final title = layoutText(
        id: 'title',
        value: s.title,
        xPx: contentX,
        yPx: y,
        maxWidthPx: contentMaxW,
        fontSize: 32,
        fontWeight: 7,
        height: 1.15,
      );
      els.add(title);
      y += _px(title.h, _dh) + 24;

      for (var i = 0; i < s.points.length; i++) {
        final point = layoutText(
          id: 'p$i',
          value: '·  ${s.points[i]}',
          xPx: contentX,
          yPx: y,
          maxWidthPx: contentMaxW,
          fontSize: 17,
          height: 1.4,
        );
        els.add(point);
        y += _px(point.h, _dh) + 12;
      }

      if (hasImg) {
        els.add(
          tightImage(
            id: 'img',
            src: s.imageAsset!,
            panelX: _dw / 2 + 8,
            panelY: 28,
            panelW: _dw / 2 - 8 - 36,
            panelH: _dh - 28 - 28,
          ),
        );
      }
      return els;

    case DiagramSlide s:
      // Padding fromLTRB(36, 28, 36, 20) — Bild in Expanded-Mitte.
      const padL = 36.0;
      const padT = 28.0;
      const padR = 36.0;
      const padB = 20.0;
      final contentW = _dw - padL - padR;
      var y = padT;
      final els = <OverlayEl>[
        layoutText(
          id: 'kicker',
          value: s.kicker.toUpperCase(),
          xPx: padL,
          yPx: y,
          maxWidthPx: contentW,
          fontSize: 12,
          color: '#1F8F84',
          fontWeight: 6,
          height: 1.0,
          letterSpacing: 1.2,
        ),
      ];
      y += _px(els.last.h, _dh) + 8;
      els.add(
        layoutText(
          id: 'title',
          value: s.title,
          xPx: padL,
          yPx: y,
          maxWidthPx: contentW,
          fontSize: 28,
          fontWeight: 7,
          height: 1.15,
        ),
      );
      y += _px(els.last.h, _dh) + 16;
      final cap = measureOverlayText(
        s.caption,
        fontSize: 14,
        height: 1.35,
        maxWidth: contentW,
      );
      final imgTop = y;
      final imgBottom = _dh - padB - cap.height - 12;
      els.add(
        tightImage(
          id: 'img',
          src: s.imageAsset,
          panelX: padL,
          panelY: imgTop,
          panelW: contentW,
          panelH: math.max(80, imgBottom - imgTop),
        ),
      );
      els.add(
        layoutText(
          id: 'cap',
          value: s.caption,
          xPx: padL,
          yPx: _dh - padB - cap.height,
          maxWidthPx: contentW,
          fontSize: 14,
          color: '#5A6A75',
          height: 1.35,
        ),
      );
      return els;

    case FlowSlide s:
      // Wie _FlowSlideView: links Steuerung, rechts HUD/OLED-Display.
      const padL = 28.0;
      const padR = 28.0;
      const padT = 24.0;
      const padB = 20.0;
      const gap = 18.0;
      final contentW = _dw - padL - padR;
      final leftW = (contentW - gap) / 2;
      final rightW = (contentW - gap) / 2;
      final leftX = padL;
      final rightX = padL + leftW + gap;
      final leftMax = leftW;
      final panelH = _dh - padT - padB;

      final els = <OverlayEl>[];
      var y = padT;

      void advance(OverlayEl el, [double extra = 0]) {
        y += _px(el.h, _dh) + extra;
      }

      final kicker = layoutText(
        id: 'kicker',
        value: s.kicker.toUpperCase(),
        xPx: leftX,
        yPx: y,
        maxWidthPx: leftMax,
        fontSize: 12,
        color: '#1F8F84',
        fontWeight: 6,
        height: 1.0,
        letterSpacing: 1.2,
        tightWidth: true,
      );
      els.add(kicker);
      advance(kicker, 8);

      final title = layoutText(
        id: 'title',
        value: s.title,
        xPx: leftX,
        yPx: y,
        maxWidthPx: leftMax,
        fontSize: 28,
        fontWeight: 8,
        height: 1.15,
        tightWidth: false,
      );
      els.add(title);
      advance(title, 8);

      final cap = layoutText(
        id: 'cap',
        value: s.caption,
        xPx: leftX,
        yPx: y,
        maxWidthPx: leftMax,
        fontSize: 14,
        color: '#5A6A75',
        height: 1.35,
        tightWidth: false,
      );
      els.add(cap);
      advance(cap, 20);

      // Phasen-Chips
      var chipX = leftX;
      const chipH = 40.0;
      for (var i = 0; i < s.steps.length; i++) {
        final step = s.steps[i];
        final tone = switch (step.tone) {
          FlowTone.green => '#2F9E6B',
          FlowTone.blue => '#3A7BD5',
          FlowTone.yellow => '#C9922A',
          FlowTone.neutral => '#6A7680',
        };
        final tw =
            measureOverlayText(step.label, fontSize: 13, fontWeight: 8).width +
                32;
        if (chipX + tw > leftX + leftMax && chipX > leftX) {
          chipX = leftX;
          y += chipH + 8;
        }
        els.add(
          box(
            id: 'step$i',
            value: step.label,
            x: _pctX(chipX),
            y: _pctY(y),
            w: _pctX(tw),
            h: _pctY(chipH),
            fontSize: 13,
            color: '#FFFFFF',
            bg: tone,
            align: 'center',
            fontWeight: 8,
            radius: 12,
            pad: 8,
            module: 'tag',
          ),
        );
        chipX += tw + 8;
        if (i < s.steps.length - 1) {
          // kleiner Pfeil als Text
          els.add(
            layoutText(
              id: 'arr$i',
              value: '→',
              xPx: chipX,
              yPx: y + 10,
              maxWidthPx: 20,
              fontSize: 14,
              color: '#5A6A75',
              tightWidth: true,
            ),
          );
          chipX += 22;
        }
      }
      y += chipH + 16;

      var tx = leftX;
      for (var i = 0; i < s.transitions.length; i++) {
        final label = s.transitions[i];
        final tw =
            measureOverlayText(label, fontSize: 12, maxWidth: 200).width + 28;
        if (tx + tw > leftX + leftMax && tx > leftX) {
          tx = leftX;
          y += 36;
        }
        els.add(
          box(
            id: 'tr$i',
            value: label,
            x: _pctX(tx),
            y: _pctY(y),
            w: _pctX(tw),
            h: _pctY(32),
            fontSize: 12,
            color: '#1A2228',
            bg: 'rgba(255,255,255,0.85)',
            borderColor: 'rgba(26,34,40,0.25)',
            align: 'center',
            radius: 16,
            pad: 6,
            module: 'tag',
          ),
        );
        tx += tw + 8;
      }
      y += 40;

      // Detail wie in _FlowSlideView (Idle-Startzustand)
      final detail = layoutText(
        id: 'detail',
        value:
            'Slot tippen (Sidebar/Keypad) setzt selectedSlotCode. Display zeigt Idle.',
        xPx: leftX,
        yPx: y,
        maxWidthPx: leftMax,
        fontSize: 13,
        color: '#1A2228',
        height: 1.4,
        tightWidth: false,
      );
      els.add(detail);

      final tip = layoutText(
        id: 'tip',
        value: 'Tipp: Phasen oder Chips antippen — das Display aktualisiert sich.',
        xPx: leftX,
        yPx: _dh - padB - 36,
        maxWidthPx: leftMax,
        fontSize: 12,
        color: '#8A969E',
        height: 1.3,
        tightWidth: false,
      );
      els.add(tip);

      // Rechts: ein skalierbares HUD-Display (wie Play)
      els.add(
        box(
          id: 'hud',
          value:
              'HUD / OLED  ·  BEREIT\n\nWÄHLE DEIN PRODUKT\nCode eingeben  ·  z. B. A1\n\nMünzen einwerfen · Preis bezahlen',
          x: _pctX(rightX),
          y: _pctY(padT),
          w: _pctX(rightW),
          h: _pctY(panelH),
          fontSize: 14,
          lineHeight: 1.35,
          color: '#00F2FE',
          bg: '#0B0F14',
          borderColor: 'rgba(0,242,254,0.7)',
          align: 'center',
          fontWeight: 8,
          radius: 16,
          pad: 16,
          module: 'hud',
        ),
      );
      return els;

    case CodeSlide s:
      // Identisch zu _CodeSlideView — Play & Edit nutzen dieselbe Materialize-Quelle.
      const padL = 24.0;
      const padR = 24.0;
      const padT = 20.0;
      const padB = 16.0;
      const gap = 14.0;
      final contentW = _dw - padL - padR;
      final leftW = (contentW - gap) * 5 / 11;
      final rightW = (contentW - gap) * 6 / 11;
      final leftX = padL;
      final rightX = padL + leftW + gap;
      final leftMax = leftW;
      final panelH = _dh - padT - padB;

      final els = <OverlayEl>[];
      var y = padT;

      void advance(OverlayEl el, [double extra = 0]) {
        y += _px(el.h, _dh) + extra;
      }

      final kicker = layoutText(
        id: 'kicker',
        value: s.kicker.toUpperCase(),
        xPx: leftX,
        yPx: y,
        maxWidthPx: leftMax,
        fontSize: 12,
        color: '#1F8F84',
        fontWeight: 6,
        height: 1.0,
        letterSpacing: 1.2,
        tightWidth: true,
      );
      els.add(kicker);
      advance(kicker, 6);

      final title = layoutText(
        id: 'title',
        value: s.title,
        xPx: leftX,
        yPx: y,
        maxWidthPx: leftMax,
        fontSize: 24,
        fontWeight: 8,
        height: 1.15,
        tightWidth: false,
      );
      els.add(title);
      advance(title, 10);

      if (s.summary.isNotEmpty) {
        // Icon 18 + gap 8 + pad 24 — wie SlideView-Callout
        final innerW = leftMax - 24 - 26;
        final sumSize = measureOverlayText(
          s.summary,
          fontSize: 13.5,
          fontWeight: 6,
          height: 1.35,
          maxWidth: innerW,
        );
        final sumH = sumSize.height + 20;
        els.add(
          box(
            id: 'summary',
            value: s.summary,
            x: _pctX(leftX),
            y: _pctY(y),
            w: _pctX(leftMax),
            h: _pctY(sumH),
            fontSize: 13.5,
            lineHeight: 1.35,
            color: '#1A2228',
            bg: 'rgba(31,143,132,0.10)',
            borderColor: 'rgba(31,143,132,0.35)',
            fontWeight: 6,
            radius: 12,
            pad: 12,
            module: 'hint',
          ),
        );
        y += sumH + 12;
      }

      final fileLab = layoutText(
        id: 'fileLabel',
        value: 'Datei im Projekt (Root)',
        xPx: leftX,
        yPx: y,
        maxWidthPx: leftMax,
        fontSize: 11,
        color: '#1F8F84',
        fontWeight: 8,
        letterSpacing: 0.7,
        tightWidth: true,
        module: 'section_folder',
      );
      els.add(fileLab);
      // Platz für Icon in der Section-Zeile
      fileLab.w = math.min(_pctX(leftMax), fileLab.w + _pctX(24));
      fileLab.h = math.max(fileLab.h, _pctY(18));
      advance(fileLab, 4);

      final filePath = layoutText(
        id: 'file',
        value: s.file,
        xPx: leftX,
        yPx: y,
        maxWidthPx: leftMax,
        fontSize: 11.5,
        fontWeight: 6,
        height: 1.35,
        fontFamily: 'Consolas',
        tightWidth: false,
      );
      els.add(filePath);
      advance(filePath, 12);

      final exLab = layoutText(
        id: 'exLabel',
        value: 'In einfachen Worten',
        xPx: leftX,
        yPx: y,
        maxWidthPx: leftMax,
        fontSize: 11,
        color: '#1F8F84',
        fontWeight: 8,
        letterSpacing: 0.7,
        tightWidth: true,
        module: 'section_book',
      );
      els.add(exLab);
      exLab.w = math.min(_pctX(leftMax), exLab.w + _pctX(24));
      exLab.h = math.max(exLab.h, _pctY(18));
      advance(exLab, 6);

      const badge = 22.0;
      for (var i = 0; i < s.explanation.length; i++) {
        els.add(
          box(
            id: 'exNum$i',
            value: '${i + 1}',
            x: _pctX(leftX),
            y: _pctY(y),
            w: _pctX(badge),
            h: _pctY(badge),
            fontSize: 11,
            color: '#FFFFFF',
            bg: '#1F8F84',
            align: 'center',
            fontWeight: 8,
            radius: 6,
            pad: 0,
            module: 'badge',
          ),
        );
        final body = layoutText(
          id: 'ex$i',
          value: s.explanation[i],
          xPx: leftX + badge + 8,
          yPx: y,
          maxWidthPx: leftMax - badge - 8,
          fontSize: 13,
          height: 1.35,
          tightWidth: false,
        );
        els.add(body);
        y += math.max(badge, _px(body.h, _dh)) + 6;
      }

      y += 8;
      var tagX = leftX;
      var tagRowY = y;
      for (var i = 0; i < s.tags.length; i++) {
        final tag = s.tags[i];
        final tw =
            measureOverlayText(tag, fontSize: 11, maxWidth: 220).width + 24;
        if (tagX + tw > leftX + leftMax && tagX > leftX) {
          tagX = leftX;
          tagRowY += 30;
        }
        els.add(
          box(
            id: 'tag$i',
            value: tag,
            x: _pctX(tagX),
            y: _pctY(tagRowY),
            w: _pctX(tw),
            h: _pctY(28),
            fontSize: 11,
            color: '#1A2228',
            bg: 'rgba(31,143,132,0.12)',
            align: 'center',
            radius: 16,
            pad: 6,
            module: 'tag',
          ),
        );
        tagX += tw + 6;
      }

      els.add(
        box(
          id: 'codePanel',
          value: '',
          x: _pctX(rightX),
          y: _pctY(padT),
          w: _pctX(rightW),
          h: _pctY(panelH),
          fontSize: 1,
          color: '#E8EEF2',
          bg: '#151A1F',
          radius: 14,
          pad: 0,
          module: 'code_panel',
        ),
      );
      const headH = 40.0;
      els.add(
        box(
          id: 'codeHead',
          value: s.file,
          x: _pctX(rightX),
          y: _pctY(padT),
          w: _pctX(rightW),
          h: _pctY(headH),
          fontSize: 10.5,
          color: 'rgba(255,255,255,0.55)',
          bg: 'rgba(255,255,255,0.06)',
          fontWeight: 5,
          fontFamily: 'Consolas',
          radius: 0,
          pad: 12,
          module: 'code_head',
        ),
      );
      els.add(
        box(
          id: 'codeBody',
          value: s.code.join('\n'),
          x: _pctX(rightX),
          y: _pctY(padT + headH),
          w: _pctX(rightW),
          h: _pctY(panelH - headH),
          fontSize: 12.5,
          lineHeight: 1.45,
          color: '#E8EEF2',
          bg: 'transparent',
          fontFamily: 'Consolas',
          radius: 0,
          pad: 16,
          module: 'code_body',
        ),
      );
      return els;

    case StatusSlide s:
      // 1:1 wie _StatusSlideView: Kicker/Titel/Intro + IST/SOLL-Karten.
      const padL = 36.0;
      const padR = 36.0;
      const padT = 28.0;
      const gap = 18.0;
      final contentW = _dw - padL - padR;
      final colW = (contentW - gap) / 2;
      final leftX = padL;
      final rightX = padL + colW + gap;

      final els = <OverlayEl>[
        layoutText(
          id: 'kicker',
          value: s.kicker.toUpperCase(),
          xPx: leftX,
          yPx: padT,
          maxWidthPx: contentW,
          fontSize: 12,
          color: '#1F8F84',
          fontWeight: 6,
          height: 1.0,
          letterSpacing: 1.2,
          tightWidth: true,
        ),
        layoutText(
          id: 'title',
          value: s.title,
          xPx: leftX,
          yPx: padT + 20,
          maxWidthPx: contentW,
          fontSize: 28,
          fontWeight: 8,
          height: 1.15,
          tightWidth: false,
        ),
        layoutText(
          id: 'intro',
          value: s.intro,
          xPx: leftX,
          yPx: padT + 56,
          maxWidthPx: contentW,
          fontSize: 14,
          color: '#5A6A75',
          height: 1.35,
          tightWidth: false,
        ),
        // IST = Accent-Grün (wie Play), SOLL = Gold (wie Play) — nicht vertauschen!
        layoutText(
          id: 'nowH',
          value: 'IST',
          xPx: leftX,
          yPx: padT + 96,
          maxWidthPx: colW,
          fontSize: 16,
          color: '#1F8F84',
          fontWeight: 8,
          tightWidth: true,
        ),
        layoutText(
          id: 'nextH',
          value: 'SOLL',
          xPx: rightX,
          yPx: padT + 96,
          maxWidthPx: colW,
          fontSize: 16,
          color: '#C9922A',
          fontWeight: 8,
          tightWidth: true,
        ),
      ];

      const cardH = 88.0;
      const cardGap = 8.0;
      var yNow = padT + 128.0;
      for (var i = 0; i < s.now.length; i++) {
        final it = s.now[i];
        els.add(
          box(
            id: 'nowCard$i',
            value: '${it.title}\n${it.detail}',
            x: _pctX(leftX),
            y: _pctY(yNow),
            w: _pctX(colW),
            h: _pctY(cardH),
            fontSize: 14,
            lineHeight: 1.35,
            color: '#1A2228',
            bg: 'rgba(255,255,255,0.78)',
            borderColor: 'rgba(31,143,132,0.18)',
            radius: 12,
            pad: 10,
            module: 'status_card',
            src: it.imageAsset,
          ),
        );
        yNow += cardH + cardGap;
      }

      var yNext = padT + 128.0;
      for (var i = 0; i < s.next.length; i++) {
        final it = s.next[i];
        els.add(
          box(
            id: 'nextCard$i',
            value: '${it.title}\n${it.detail}',
            x: _pctX(rightX),
            y: _pctY(yNext),
            w: _pctX(colW),
            h: _pctY(cardH),
            fontSize: 14,
            lineHeight: 1.35,
            color: '#1A2228',
            bg: 'rgba(255,255,255,0.78)',
            borderColor: 'rgba(201,146,42,0.18)',
            radius: 12,
            pad: 10,
            module: 'status_card',
            src: it.imageAsset,
          ),
        );
        yNext += cardH + cardGap;
      }
      return els;

    case ClosingSlide s:
      final els = <OverlayEl>[
        layoutText(
          id: 'title',
          value: s.title,
          xPx: 120,
          yPx: 280,
          maxWidthPx: 1360,
          fontSize: 48,
          align: 'center',
          fontWeight: 7,
          height: 1.1,
        ),
      ];
      for (var i = 0; i < s.lines.length; i++) {
        els.add(
          layoutText(
            id: 'p$i',
            value: s.lines[i],
            xPx: 200,
            yPx: 400.0 + i * 48,
            maxWidthPx: 1200,
            fontSize: 18,
            color: '#5A6A75',
            align: 'center',
            height: 1.3,
          ),
        );
      }
      return els;
  }
}
