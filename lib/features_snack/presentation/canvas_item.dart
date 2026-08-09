part of 'slide_editor_library.dart';

class _CanvasItem extends StatefulWidget {
  const _CanvasItem({
    super.key,
    required this.el,
    required this.selected,
    required this.primary,
    required this.editing,
    required this.parentSize,
    required this.onSelect,
    required this.onPlayTap,
    required this.onMoveStart,
    required this.onMoveTo,
    required this.onResizeTo,
    required this.onGestureEnd,
    required this.onTextCommit,
  });

  final OverlayEl el;
  final bool selected;
  final bool primary;
  final bool editing;
  final Size parentSize;
  final VoidCallback onSelect;
  final VoidCallback onPlayTap;
  final VoidCallback onMoveStart;
  final void Function(double x, double y) onMoveTo;
  final void Function(double w, double h) onResizeTo;
  final VoidCallback onGestureEnd;
  final ValueChanged<String> onTextCommit;

  @override
  State<_CanvasItem> createState() => _CanvasItemState();
}

class _CanvasItemState extends State<_CanvasItem> {
  Offset? _pointerOrigin;
  double _originX = 0;
  double _originY = 0;
  double _originW = 0;
  double _originH = 0;
  bool _inlineEdit = false;
  late TextEditingController _textCtrl;

  static const _handle = 28.0;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.el.text ?? '');
  }

  @override
  void didUpdateWidget(covariant _CanvasItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.el.id != widget.el.id ||
        (!_inlineEdit && oldWidget.el.text != widget.el.text)) {
      _textCtrl.text = widget.el.text ?? '';
    }
    if (!widget.selected && _inlineEdit) _inlineEdit = false;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  TextAlign get _textAlign => switch (widget.el.align) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        _ => TextAlign.left,
      };

  Alignment get _boxAlign => switch (widget.el.align) {
        'center' => Alignment.center,
        'right' => Alignment.centerRight,
        _ => Alignment.topLeft,
      };

  FontWeight get _weight {
    const weights = <FontWeight>[
      FontWeight.w100,
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ];
    return weights[widget.el.fontWeight.clamp(0, weights.length - 1)];
  }

  BoxFit get _boxFit {
    switch (widget.el.fit) {
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      default:
        return BoxFit.cover;
    }
  }

  void _beginGesture(Offset global, {required bool forResize}) {
    if (!forResize) {
      widget.onMoveStart();
    }
    _pointerOrigin = global;
    _originX = widget.el.x;
    _originY = widget.el.y;
    _originW = widget.el.w;
    _originH = widget.el.h;
  }

  void _applyMove(Offset global) {
    final origin = _pointerOrigin;
    final pw = widget.parentSize.width;
    final ph = widget.parentSize.height;
    if (origin == null || pw <= 0 || ph <= 0) return;
    final dx = (global.dx - origin.dx) / pw * 100;
    final dy = (global.dy - origin.dy) / ph * 100;
    final maxX = math.max(0.0, 100 - _originW);
    final maxY = math.max(0.0, 100 - _originH);
    widget.onMoveTo(
      (_originX + dx).clamp(0, maxX),
      (_originY + dy).clamp(0, maxY),
    );
  }

  void _applyResize(Offset global) {
    final origin = _pointerOrigin;
    final pw = widget.parentSize.width;
    final ph = widget.parentSize.height;
    if (origin == null || pw <= 0 || ph <= 0) return;
    final dx = (global.dx - origin.dx) / pw * 100;
    final dy = (global.dy - origin.dy) / ph * 100;
    final maxW = math.max(4.0, 100 - _originX);
    final maxH = math.max(4.0, 100 - _originY);
    widget.onResizeTo(
      (_originW + dx).clamp(4, maxW),
      (_originH + dy).clamp(4, maxH),
    );
  }

  Widget _imageContent() {
    final el = widget.el;
    final src = el.src;
    if (src == null) {
      return const ColoredBox(color: Color(0x22000000));
    }

    Widget img;
    if (src.startsWith('assets/')) {
      img = Image.asset(
        src,
        fit: _boxFit,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
      );
    } else {
      img = Image.file(
        File(src),
        fit: _boxFit,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) =>
            const ColoredBox(color: Color(0x44000000)),
      );
    }

    final visibleW = (1 - el.cropL - el.cropR).clamp(0.2, 1.0);
    final visibleH = (1 - el.cropT - el.cropB).clamp(0.2, 1.0);
    final hasCrop = el.cropL + el.cropR + el.cropT + el.cropB > 0.001;
    if (!hasCrop) {
      return SizedBox.expand(child: img);
    }

    final midX = el.cropL + visibleW / 2;
    final midY = el.cropT + visibleH / 2;
    return ClipRect(
      child: SizedBox.expand(
        child: Align(
          alignment: Alignment(midX * 2 - 1, midY * 2 - 1),
          widthFactor: 1 / visibleW,
          heightFactor: 1 / visibleH,
          child: img,
        ),
      ),
    );
  }

  Widget _content() {
    final el = widget.el;
    final mod = el.module;
    final fg = parseCssColor(el.color) ?? PresentationTheme.ink;
    final bgRaw = el.bg;
    final bgTransparent =
        bgRaw == null || bgRaw.isEmpty || bgRaw == 'transparent';
    final bg = bgTransparent ? null : parseCssColor(bgRaw);
    final border = parseCssColor(el.borderColor);
    final radius = el.radius ?? (el.kind == OverlayKind.box ? 10.0 : 0.0);
    final pad = el.pad ?? (el.kind == OverlayKind.box ? 10.0 : 0.0);
    final BorderRadius borderRadius;
    if (mod == 'code_head' || el.id.endsWith('_codeHead')) {
      borderRadius = const BorderRadius.vertical(top: Radius.circular(14));
    } else if (mod == 'code_body' || el.id.endsWith('_codeBody')) {
      borderRadius = const BorderRadius.vertical(bottom: Radius.circular(14));
    } else if (mod == 'code_panel' || el.id.endsWith('_codePanel')) {
      borderRadius = BorderRadius.circular(14);
    } else {
      borderRadius = BorderRadius.circular(radius);
    }

    TextStyle textStyle({Color? color, double? size, FontWeight? weight}) =>
        TextStyle(
          color: color ?? fg,
          fontSize: size ?? el.fontSize ?? (el.kind == OverlayKind.box ? 16 : 20),
          fontWeight: weight ?? _weight,
          height: el.lineHeight ?? (el.kind == OverlayKind.box ? 1.3 : 1.25),
          fontFamily: el.fontFamily,
        );

    BoxDecoration boxDeco({Color? fill}) {
      final Color? c;
      if (fill != null) {
        c = fill;
      } else if (bgTransparent) {
        c = Colors.transparent;
      } else {
        c = bg ?? const Color(0xE0121A20);
      }
      return BoxDecoration(
        color: c,
        borderRadius: borderRadius,
        border: border == null ? null : Border.all(color: border),
      );
    }

    Widget editableOrText({
      required TextStyle style,
      TextAlign align = TextAlign.left,
      int? maxLines,
    }) {
      if (_inlineEdit && widget.editing) {
        return TextField(
          controller: _textCtrl,
          autofocus: true,
          maxLines: maxLines,
          textAlign: align,
          style: style,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: widget.onTextCommit,
          onSubmitted: (_) => setState(() => _inlineEdit = false),
        );
      }
      return Text(
        el.text ?? '',
        textAlign: align,
        softWrap: true,
        maxLines: maxLines,
        overflow: TextOverflow.visible,
        style: style,
      );
    }

    // --- Feste Module (1:1 wie SlideView) ---
    if (mod == 'hint') {
      return Container(
        clipBehavior: Clip.none,
        decoration: boxDeco(
          fill: bg ?? PresentationTheme.accent.withValues(alpha: 0.1),
        ),
        padding: EdgeInsets.all(pad),
        alignment: Alignment.topLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: PresentationTheme.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: editableOrText(
                style: textStyle(weight: FontWeight.w600, size: 13.5),
              ),
            ),
          ],
        ),
      );
    }

    if (mod == 'section_folder' || mod == 'section_book') {
      final icon = mod == 'section_folder'
          ? Icons.folder_open
          : Icons.menu_book_outlined;
      final label = (el.text ?? '').toUpperCase();
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, size: 15, color: PresentationTheme.accent),
            const SizedBox(width: 6),
            Flexible(
              child: _inlineEdit && widget.editing
                  ? TextField(
                      controller: _textCtrl,
                      autofocus: true,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: PresentationTheme.accent,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: widget.onTextCommit,
                      onSubmitted: (_) => setState(() => _inlineEdit = false),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: PresentationTheme.accent,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    if (mod == 'badge') {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg ?? PresentationTheme.accent,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: editableOrText(
          style: textStyle(color: Colors.white, size: 11, weight: FontWeight.w800),
          align: TextAlign.center,
          maxLines: 1,
        ),
      );
    }

    if (mod == 'tag') {
      return Container(
        alignment: Alignment.center,
        decoration: boxDeco(
          fill: bg ?? PresentationTheme.accent.withValues(alpha: 0.12),
        ),
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 2),
        child: editableOrText(
          style: textStyle(size: 11),
          align: TextAlign.center,
          maxLines: 1,
        ),
      );
    }

    if (mod == 'code_panel') {
      return DecoratedBox(decoration: boxDeco(fill: const Color(0xFF151A1F)));
    }

    if (mod == 'hud_panel' || mod == 'hud') {
      final lines = (el.text ?? '').split('\n');
      final head = lines.isNotEmpty ? lines.first : 'HUD / OLED';
      final title = lines.length > 2 ? lines[2] : 'WÄHLE DEIN PRODUKT';
      final sub = lines.length > 3 ? lines[3] : '';
      final foot = lines.length > 5
          ? lines[5]
          : (lines.length > 4 ? lines.last : '');
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F14),
          borderRadius: BorderRadius.circular(radius > 0 ? radius : 16),
          border: Border.all(
            color: border ?? const Color(0xB300F2FE),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
              blurRadius: 18,
            ),
          ],
        ),
        padding: EdgeInsets.all(pad > 0 ? pad : 16),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 280,
            height: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00F2FE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        head,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (_inlineEdit && widget.editing)
                  editableOrText(
                    style: textStyle(
                      color: const Color(0xFF00F2FE),
                      size: 18,
                      weight: FontWeight.w800,
                    ),
                    align: TextAlign.center,
                  )
                else ...[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF00F2FE),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  foot,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (mod == 'status_card') {
      final raw = el.text ?? '';
      final split = raw.indexOf('\n');
      final title = split < 0 ? raw : raw.substring(0, split);
      final detail = split < 0 ? '' : raw.substring(split + 1);
      final accent = border ?? PresentationTheme.accent;
      return Container(
        decoration: BoxDecoration(
          color: bg ?? Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(radius > 0 ? radius : 12),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        padding: EdgeInsets.all(pad > 0 ? pad : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (el.src != null && el.src!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  el.src!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 56,
                    height: 56,
                    color: accent.withValues(alpha: 0.12),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_outlined,
                      color: accent,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle(
                      weight: FontWeight.w700,
                      size: 14,
                      color: PresentationTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle(
                        size: 12.5,
                        color: PresentationTheme.muted,
                      ).copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (mod == 'video') {
      return Container(
        clipBehavior: Clip.none,
        decoration: boxDeco(fill: const Color(0xFF151A1F)),
        padding: EdgeInsets.all(pad),
        alignment: Alignment.center,
        child: editableOrText(
          style: textStyle(size: 13),
          align: TextAlign.center,
        ),
      );
    }

    if (mod == 'code_head') {
      return Container(
        decoration: boxDeco(fill: Colors.white.withValues(alpha: 0.06)),
        padding: EdgeInsets.all(pad),
        child: Row(
          children: [
            const Icon(Icons.code, size: 16, color: Color(0xFF7DDBD0)),
            const SizedBox(width: 8),
            const Text(
              'CODE',
              style: TextStyle(
                color: Color(0xFF7DDBD0),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: editableOrText(
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10.5,
                  fontFamily: 'Consolas',
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }

    if (mod == 'code_body') {
      return Container(
        alignment: Alignment.topLeft,
        padding: EdgeInsets.all(pad),
        child: editableOrText(
          style: textStyle(size: 12.5),
        ),
      );
    }

    switch (el.kind) {
      case OverlayKind.text:
        if (_inlineEdit && widget.editing) {
          return Container(
            color: bg ?? Colors.white70,
            padding: EdgeInsets.all(pad > 0 ? pad : 4),
            child: TextField(
              controller: _textCtrl,
              autofocus: true,
              maxLines: null,
              textAlign: _textAlign,
              style: textStyle(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onTextCommit,
              onSubmitted: (_) => setState(() => _inlineEdit = false),
            ),
          );
        }
        return SizedBox.expand(
          child: Align(
            alignment: _boxAlign,
            child: Text(
              el.text ?? '',
              textAlign: _textAlign,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: textStyle(),
            ),
          ),
        );
      case OverlayKind.box:
        final deco = boxDeco();
        if (_inlineEdit && widget.editing) {
          return Container(
            clipBehavior: Clip.none,
            decoration: deco,
            padding: EdgeInsets.all(pad),
            alignment: _boxAlign,
            child: TextField(
              controller: _textCtrl,
              autofocus: true,
              maxLines: null,
              textAlign: _textAlign,
              style: textStyle(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onTextCommit,
              onSubmitted: (_) => setState(() => _inlineEdit = false),
            ),
          );
        }
        final label = el.text ?? '';
        return Container(
          clipBehavior: Clip.none,
          alignment: _boxAlign,
          decoration: deco,
          padding: EdgeInsets.all(pad),
          child: label.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  label,
                  textAlign: _textAlign,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: textStyle(),
                ),
        );
      case OverlayKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(
            el.radius ?? (widget.el.fit == 'fill' ? 16 : 10),
          ),
          child: _imageContent(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.editing) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPlayTap,
        child: _content(),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              if (!widget.editing || _inlineEdit) return;
              widget.onSelect();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: (widget.el.kind == OverlayKind.text ||
                      widget.el.kind == OverlayKind.box)
                  ? () {
                      widget.onSelect();
                      setState(() {
                        _inlineEdit = true;
                        _textCtrl.text = widget.el.text ?? '';
                      });
                    }
                  : null,
              onPanStart: _inlineEdit
                  ? null
                  : (d) => _beginGesture(d.globalPosition, forResize: false),
              onPanUpdate: _inlineEdit
                  ? null
                  : (d) => _applyMove(d.globalPosition),
              onPanEnd: (_) {
                _pointerOrigin = null;
                widget.onGestureEnd();
              },
              onPanCancel: () {
                _pointerOrigin = null;
                widget.onGestureEnd();
              },
              child: _content(),
            ),
          ),
        ),
        if (widget.selected)
          Positioned(
            left: -1.5,
            top: -1.5,
            right: -1.5,
            bottom: -1.5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: PresentationTheme.accent
                        .withValues(alpha: widget.primary ? 1 : 0.65),
                    width: widget.primary ? 1.5 : 1.25,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
              ),
            ),
          ),
        if (widget.selected)
          Positioned(
            right: -2,
            bottom: -2,
            width: _handle,
            height: _handle,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) =>
                  _beginGesture(d.globalPosition, forResize: true),
              onPanUpdate: (d) => _applyResize(d.globalPosition),
              onPanEnd: (_) {
                _pointerOrigin = null;
                widget.onGestureEnd();
              },
              onPanCancel: () {
                _pointerOrigin = null;
                widget.onGestureEnd();
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PresentationTheme.accent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.south_east,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

