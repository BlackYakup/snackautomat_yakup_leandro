import 'package:flutter/material.dart';

class KeyButton extends StatefulWidget {
  const KeyButton({
    super.key,
    required this.label,
    required this.onPressed,
  }) : isDestructive = false;

  const KeyButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
  }) : isDestructive = true;

  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed == pressed) {
      return;
    }

    setState(() {
      _isPressed = pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    final gradientColors = widget.isDestructive
        ? [
            Colors.red.shade100,
            Colors.red.shade300,
            Colors.red.shade500,
          ]
        : [
            Colors.white,
            Colors.grey.shade300,
            Colors.grey.shade600,
          ];
    final borderColor = widget.isDestructive
        ? Colors.red.shade900
        : Colors.grey.shade800;
    final textColor = widget.isDestructive
        ? Colors.red.shade900
        : Colors.black87;

    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        height: 40,
        transform: Matrix4.translationValues(0, _isPressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: _isPressed
              ? const [
                  BoxShadow(
                    color: Colors.black38,
                    offset: Offset(0, 1),
                    blurRadius: 1,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, 4),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradientColors,
              ),
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: InkWell(
              onTapDown: isEnabled ? (_) => _setPressed(true) : null,
              onTapUp: isEnabled ? (_) => _setPressed(false) : null,
              onTapCancel: isEnabled ? () => _setPressed(false) : null,
              onTap: widget.onPressed,
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
