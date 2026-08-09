import 'package:flutter/material.dart';

/// Navigation per Doppelklick an den Seitenrändern
/// (Mitte bleibt frei für Demo-Buttons / Display).
class HoldNav extends StatefulWidget {
  const HoldNav({
    super.key,
    required this.enabled,
    required this.canForward,
    required this.canBack,
    required this.onForward,
    required this.onBack,
  });

  final bool enabled;
  final bool canForward;
  final bool canBack;
  final VoidCallback onForward;
  final VoidCallback onBack;

  static const doubleClickMs = 350;

  @override
  State<HoldNav> createState() => _HoldNavState();
}

class _HoldNavState extends State<HoldNav> {
  DateTime _lastClick = DateTime.fromMillisecondsSinceEpoch(0);
  bool _flashForward = false;
  bool _flashBack = false;

  void _onEdgeTap({required bool right}) {
    if (!widget.enabled) return;
    final now = DateTime.now();
    final isDouble =
        now.difference(_lastClick).inMilliseconds < HoldNav.doubleClickMs;
    _lastClick = now;
    if (!isDouble) return;

    if (right) {
      if (!widget.canForward) return;
      setState(() => _flashForward = true);
      widget.onForward();
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _flashForward = false);
      });
    } else {
      if (!widget.canBack) return;
      setState(() => _flashBack = true);
      widget.onBack();
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _flashBack = false);
      });
    }
    _lastClick = DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.08,
            heightFactor: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _onEdgeTap(right: false),
              child: ColoredBox(
                color: _flashBack
                    ? const Color(0xFFE85A5A).withValues(alpha: 0.14)
                    : Colors.transparent,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.08,
            heightFactor: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _onEdgeTap(right: true),
              child: ColoredBox(
                color: _flashForward
                    ? const Color(0xFF1F8F84).withValues(alpha: 0.14)
                    : Colors.transparent,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                'Doppelklick am Rand: links zurück · rechts weiter',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
