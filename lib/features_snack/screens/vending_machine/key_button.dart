import 'package:flutter/material.dart';

/// Metall-Tasten im Automaten-Look (Referenz: gebürstetes Bedienfeld, X rot, OK grün).
enum KeyButtonStyle {
  /// Ziffern 0–9
  metal,
  /// Buchstaben A–F (etwas dunkler/kühler, klar unterscheidbar)
  letter,
  cancel,
  confirm,
}

class KeyButton extends StatefulWidget {
  const KeyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = KeyButtonStyle.metal,
    this.size = 34,
  });

  const KeyButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = 34,
  }) : style = KeyButtonStyle.cancel;

  final String label;
  final VoidCallback? onPressed;
  final KeyButtonStyle style;
  final double size;

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed == pressed) return;
    setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final radius = BorderRadius.circular(widget.size * 0.16);
    final colors = _palette(widget.style);
    final fontSize = widget.label.length > 1
        ? widget.size * 0.32
        : widget.size * 0.46;

    return Opacity(
      opacity: isEnabled ? 1 : 0.42,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
        width: widget.size,
        height: widget.size,
        transform: Matrix4.translationValues(0, _isPressed ? 1.5 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 2),
                    blurRadius: 2,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isPressed ? colors.pressed : colors.face,
              ),
              border: Border.all(color: colors.border, width: 1.1),
            ),
            child: InkWell(
              onTapDown: isEnabled ? (_) => _setPressed(true) : null,
              onTapUp: isEnabled ? (_) => _setPressed(false) : null,
              onTapCancel: isEnabled ? () => _setPressed(false) : null,
              onTap: widget.onPressed,
              child: Center(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.label,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: widget.label == 'OK' ? 0.2 : 0,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _KeyPalette _palette(KeyButtonStyle style) {
    switch (style) {
      case KeyButtonStyle.cancel:
        return const _KeyPalette(
          face: [Color(0xFFFF5A55), Color(0xFFE02020), Color(0xFFB01010)],
          pressed: [Color(0xFFC01818), Color(0xFF9A0E0E), Color(0xFF7A0A0A)],
          border: Color(0xFF5A0808),
          label: Color(0xFF111111),
        );
      case KeyButtonStyle.confirm:
        return const _KeyPalette(
          face: [Color(0xFF6DFF6A), Color(0xFF2EDB2A), Color(0xFF18A816)],
          pressed: [Color(0xFF1EBE1C), Color(0xFF149612), Color(0xFF0E700C)],
          border: Color(0xFF0A4A0A),
          label: Color(0xFF111111),
        );
      case KeyButtonStyle.letter:
        // Kühleres, dunkleres Grau → Buchstaben klar von Ziffern getrennt
        return const _KeyPalette(
          face: [Color(0xFFB8C0CC), Color(0xFF8E98A6), Color(0xFF6E7888)],
          pressed: [Color(0xFF7A8494), Color(0xFF5E6878), Color(0xFF4A5464)],
          border: Color(0xFF3A4450),
          label: Color(0xFF0E1218),
        );
      case KeyButtonStyle.metal:
        // Helleres Silber für Ziffern
        return const _KeyPalette(
          face: [Color(0xFFF2F3F5), Color(0xFFC8CCD2), Color(0xFF9EA4AE)],
          pressed: [Color(0xFFB8BCC4), Color(0xFF9A9FA8), Color(0xFF7E848E)],
          border: Color(0xFF5C616A),
          label: Color(0xFF1A1A1A),
        );
    }
  }
}

class _KeyPalette {
  const _KeyPalette({
    required this.face,
    required this.pressed,
    required this.border,
    required this.label,
  });

  final List<Color> face;
  final List<Color> pressed;
  final Color border;
  final Color label;
}
