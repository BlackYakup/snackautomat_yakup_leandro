part of 'slide_editor_library.dart';

class PresentationEditorDock extends StatelessWidget {
  const PresentationEditorDock({
    super.key,
    required this.selected,
    required this.onAddText,
    required this.onAddBox,
    required this.onAddHint,
    required this.onAddStep,
    required this.onAddSection,
    required this.onAddTitleBody,
    required this.onPickImage,
    required this.onReset,
    required this.onDelete,
    required this.onBringForward,
    required this.onPatch,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
  });

  final OverlayEl? selected;
  final VoidCallback onAddText;
  final VoidCallback onAddBox;
  final VoidCallback onAddHint;
  final VoidCallback onAddStep;
  final VoidCallback onAddSection;
  final VoidCallback onAddTitleBody;
  final VoidCallback onPickImage;
  final VoidCallback? onReset;
  final VoidCallback? onDelete;
  final VoidCallback? onBringForward;
  final void Function(void Function(OverlayEl)) onPatch;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  static const _bg = Color(0xFF12171C);
  static const _card = Color(0xFF1B2229);
  static const _line = Color(0xFF2A333C);

  @override
  Widget build(BuildContext context) {
    final sel = selected;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(-6, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: PresentationTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Strg+Z/Y · Strg+C/V · Ecke = skalieren',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: _ToolTile(
                    icon: Icons.undo_rounded,
                    label: 'Zurück',
                    onTap: canUndo ? onUndo : null,
                    muted: !canUndo,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToolTile(
                    icon: Icons.redo_rounded,
                    label: 'Vor',
                    onTap: canRedo ? onRedo : null,
                    muted: !canRedo,
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.65,
                    children: [
                      _ToolTile(
                        icon: Icons.title_rounded,
                        label: 'Text',
                        onTap: onAddText,
                      ),
                      _ToolTile(
                        icon: Icons.crop_square_rounded,
                        label: 'Kasten',
                        onTap: onAddBox,
                      ),
                      _ToolTile(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Hinweis',
                        onTap: onAddHint,
                      ),
                      _ToolTile(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Schritt',
                        onTap: onAddStep,
                      ),
                      _ToolTile(
                        icon: Icons.label_outline_rounded,
                        label: 'Abschnitt',
                        onTap: onAddSection,
                      ),
                      _ToolTile(
                        icon: Icons.short_text_rounded,
                        label: 'Titel+Text',
                        onTap: onAddTitleBody,
                      ),
                      _ToolTile(
                        icon: Icons.add_photo_alternate_outlined,
                        label: 'Bild',
                        onTap: onPickImage,
                      ),
                      _ToolTile(
                        icon: Icons.restart_alt_rounded,
                        label: 'Reset',
                        onTap: onReset,
                        muted: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (sel == null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: Text(
                        'Element anklicken.\n'
                        'Strg+Klick = Mehrfachauswahl\n'
                        'Leerfläche ziehen = Rahmen\n'
                        'Ecke = skalieren\n'
                        'Strg+Z = zurück',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // reuse existing selected panel content by keeping below
                          _SelectedInspector(
                            selected: sel,
                            onDelete: onDelete,
                            onBringForward: onBringForward,
                            onPatch: onPatch,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedInspector extends StatelessWidget {
  const _SelectedInspector({
    required this.selected,
    required this.onDelete,
    required this.onBringForward,
    required this.onPatch,
  });

  final OverlayEl selected;
  final VoidCallback? onDelete;
  final VoidCallback? onBringForward;
  final void Function(void Function(OverlayEl)) onPatch;

  static const _bg = Color(0xFF12171C);
  static const _line = Color(0xFF2A333C);

  @override
  Widget build(BuildContext context) {
    final sel = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _kindLabel(sel),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MiniAction(
                icon: Icons.flip_to_front_rounded,
                label: 'Vorne',
                onTap: onBringForward,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniAction(
                icon: Icons.delete_outline_rounded,
                label: 'Löschen',
                danger: true,
                onTap: onDelete,
              ),
            ),
          ],
        ),
        if (sel.kind == OverlayKind.text || sel.kind == OverlayKind.box) ...[
          const SizedBox(height: 14),
          _fieldLabel('Inhalt'),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('txt_${sel.id}'),
            initialValue: sel.text ?? '',
            maxLines: 5,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDeco(),
            onChanged: (v) => onPatch((e) => e.text = v),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Schrift ${(sel.fontSize ?? 16).round()}'),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: PresentationTheme.accent,
              thumbColor: Colors.white,
              inactiveTrackColor: _line,
            ),
            child: Slider(
              value: (sel.fontSize ?? 16).clamp(8, 72),
              min: 8,
              max: 72,
              onChanged: (v) => onPatch((e) => e.fontSize = v),
            ),
          ),
          _fieldLabel('Ausrichtung'),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) return Colors.white;
                return Colors.white54;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) {
                  return PresentationTheme.accent;
                }
                return _bg;
              }),
            ),
            segments: const [
              ButtonSegment(
                value: 'left',
                icon: Icon(Icons.format_align_left, size: 16),
              ),
              ButtonSegment(
                value: 'center',
                icon: Icon(Icons.format_align_center, size: 16),
              ),
              ButtonSegment(
                value: 'right',
                icon: Icon(Icons.format_align_right, size: 16),
              ),
            ],
            selected: {
              sel.align == 'center'
                  ? 'center'
                  : (sel.align == 'right' ? 'right' : 'left'),
            },
            onSelectionChanged: (s) => onPatch((e) => e.align = s.first),
          ),
        ],
        if (sel.kind == OverlayKind.image) ...[
          const SizedBox(height: 14),
          _fieldLabel('Einpassung'),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) return Colors.white;
                return Colors.white54;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) {
                  return PresentationTheme.accent;
                }
                return _bg;
              }),
            ),
            segments: const [
              ButtonSegment(value: 'cover', label: Text('Füllen')),
              ButtonSegment(value: 'contain', label: Text('Einpassen')),
            ],
            selected: {sel.fit == 'contain' ? 'contain' : 'cover'},
            onSelectionChanged: (s) => onPatch((e) => e.fit = s.first),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Zuschneiden'),
          _cropSlider(context, 'Links', sel.cropL, (v) => onPatch((e) => e.cropL = v)),
          _cropSlider(context, 'Rechts', sel.cropR, (v) => onPatch((e) => e.cropR = v)),
          _cropSlider(context, 'Oben', sel.cropT, (v) => onPatch((e) => e.cropT = v)),
          _cropSlider(context, 'Unten', sel.cropB, (v) => onPatch((e) => e.cropB = v)),
          TextButton(
            onPressed: () => onPatch((e) {
              e.cropL = 0;
              e.cropR = 0;
              e.cropT = 0;
              e.cropB = 0;
            }),
            child: Text(
              'Zuschnitt zurücksetzen',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ],
    );
  }

  static String _kindLabel(OverlayEl el) {
    final mod = el.module;
    if (mod == 'hud' || mod == 'hud_panel') return 'HUD / Display';
    if (mod == 'hint') return 'Hinweis';
    if (mod == 'step_num' || mod == 'step_body') return 'Schritt';
    if (mod == 'section_folder' || mod == 'section_book') return 'Abschnitt';
    if (mod == 'code_panel' || mod == 'code_head' || mod == 'code_body') {
      return 'Code-Panel';
    }
    return switch (el.kind) {
      OverlayKind.text => 'Text-Element',
      OverlayKind.box => 'Kasten',
      OverlayKind.image => 'Bild',
    };
  }

  static Widget _fieldLabel(String t) => Text(
        t,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );

  static InputDecoration _inputDeco() => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: PresentationTheme.accent),
        ),
      );

  Widget _cropSlider(
    BuildContext context,
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label ${(value * 100).round()}%',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: PresentationTheme.accent,
            thumbColor: Colors.white,
            inactiveTrackColor: _line,
          ),
          child: Slider(
            value: value.clamp(0, 0.45),
            min: 0,
            max: 0.45,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}


class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.muted = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool muted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconColor = muted
        ? Colors.white38
        : PresentationTheme.accent.withValues(alpha: 0.95);
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: muted ? 0.45 : 0.85),
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );

    return Material(
      color: muted ? const Color(0xFF171D23) : const Color(0xFF1B2229),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A333C)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 10,
            vertical: compact ? 10 : 8,
          ),
          child: compact
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: iconColor, size: 22),
                    const SizedBox(height: 6),
                    Text(label, style: labelStyle),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B6B) : Colors.white70;
    return Material(
      color: const Color(0xFF12171C),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
