part of 'vending_machine_3d_landing_screen.dart';

/// Blinkendes Auge: aktiv wenn Ware in der Ausgabe liegt; Klick → Ausgabe-Kamera.
class _DeliveryWatchEye extends StatefulWidget {
  const _DeliveryWatchEye({
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_DeliveryWatchEye> createState() => _DeliveryWatchEyeState();
}

class _DeliveryWatchEyeState extends State<_DeliveryWatchEye>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _DeliveryWatchEye oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncPulse();
  }

  void _syncPulse() {
    if (widget.active) {
      if (!_pulse.isAnimating) {
        unawaited(_pulse.repeat(reverse: true));
      }
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = widget.active ? _pulse.value : 0.0;
        final glow = Color.lerp(
          const Color(0xFF4A5560),
          const Color(0xFF00F2FE),
          t,
        )!;
        final iconColor = Color.lerp(
          Colors.white54,
          const Color(0xFFE8FFFF),
          t,
        )!;
        return _SceneCornerAction(
          icon: Icons.visibility_rounded,
          label: 'Produktausgabe',
          tooltip: widget.active
              ? 'Produkt bereit · zur Ausgabe springen'
              : 'Produktausgabe',
          enabled: widget.enabled,
          onTap: widget.onTap,
          iconColor: iconColor,
          borderColor: glow.withValues(alpha: 0.45 + 0.45 * t),
          fillColor: Color.lerp(
            const Color(0xCC1A1E24),
            const Color(0xEE003A44),
            t,
          ),
          glow: widget.active
              ? BoxShadow(
                  color: glow.withValues(alpha: 0.35 + 0.45 * t),
                  blurRadius: 10 + 14 * t,
                  spreadRadius: 1 + 2 * t,
                )
              : null,
        );
      },
    );
  }
}

/// Runde Eck-Schaltfläche mit Beschriftung darunter (Vorderansicht neu laden / Produktausgabe).
class _SceneCornerAction extends StatelessWidget {
  const _SceneCornerAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    this.iconColor,
    this.borderColor,
    this.fillColor,
    this.glow,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? borderColor;
  final Color? fillColor;
  final BoxShadow? glow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fillColor ?? const Color(0xCC1A1E24),
                  border: Border.all(
                    color: borderColor ?? const Color(0xFF4A5560).withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  boxShadow: glow == null ? null : [glow!],
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? Colors.white54,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
