part of 'digital_display_library.dart';

/// Moderne OLED-Anzeige: eine Phase zur Zeit, groß & animiert.
enum OledDisplayPhase {
  idle,
  typing,
  selected,
  payment,
  dispensing,
  success,
  outOfService,
}

class DigitalDisplay extends StatefulWidget {
  const DigitalDisplay({
    super.key,
    required this.session,
    this.compact = false,
  });

  final VendingSessionState session;
  final bool compact;

  @override
  State<DigitalDisplay> createState() => _DigitalDisplayState();
}

class _DigitalDisplayState extends State<DigitalDisplay>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF0D1117);
  static const _cyan = Color(0xFF00F2FE);
  static const _green = Color(0xFF00FF87);
  static const _yellow = Color(0xFFFFD200);

  late final AnimationController _pulseCtrl;
  late final AnimationController _cardWaveCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _cardWaveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _cardWaveCtrl.dispose();
    super.dispose();
  }

  OledDisplayPhase get _phase {
    final s = widget.session;
    switch (s.phase) {
      case VendingMachinePhase.outOfService:
        return OledDisplayPhase.outOfService;
      case VendingMachinePhase.dispensing:
        return OledDisplayPhase.dispensing;
      case VendingMachinePhase.thankYou:
        return OledDisplayPhase.success;
      case VendingMachinePhase.paymentInProgress:
        return OledDisplayPhase.payment;
      case VendingMachinePhase.ready:
        if (s.selectedProduct != null) return OledDisplayPhase.selected;
        if (s.currentSlotInput.isNotEmpty) return OledDisplayPhase.typing;
        return OledDisplayPhase.idle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phase;
    final pad = widget.compact ? 10.0 : 16.0;
    final minH = widget.compact ? 148.0 : 200.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(widget.compact ? 10 : 14),
        border: Border.all(
          color: _cyan.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _cyan.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.compact ? 10 : 14),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH),
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildChrome(phase),
                SizedBox(height: widget.compact ? 8 : 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 340),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(anim);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(phase),
                    child: _buildPhase(phase),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChrome(OledDisplayPhase phase) {
    final led = switch (phase) {
      OledDisplayPhase.idle || OledDisplayPhase.typing => _cyan,
      OledDisplayPhase.selected || OledDisplayPhase.payment => _yellow,
      OledDisplayPhase.dispensing => _cyan,
      OledDisplayPhase.success => _green,
      OledDisplayPhase.outOfService => const Color(0xFFFF4D6D),
    };

    return Row(
      children: [
        Text(
          'SNACK · OLED',
          style: TextStyle(
            color: _cyan.withValues(alpha: 0.85),
            fontSize: widget.compact ? 9 : 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const Spacer(),
        FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulseCtrl),
          child: Container(
            key: const ValueKey('status-led'),
            width: widget.compact ? 7 : 9,
            height: widget.compact ? 7 : 9,
            decoration: BoxDecoration(
              color: led,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: led, blurRadius: 10, spreadRadius: 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhase(OledDisplayPhase phase) {
    return switch (phase) {
      OledDisplayPhase.idle => _IdlePhase(
          pulse: _pulseCtrl,
          compact: widget.compact,
          statusMessage: widget.session.statusMessage,
        ),
      OledDisplayPhase.typing => _TypingPhase(
          input: widget.session.currentSlotInput,
          compact: widget.compact,
        ),
      OledDisplayPhase.selected || OledDisplayPhase.payment => _SelectedPayPhase(
          session: widget.session,
          compact: widget.compact,
          cardWave: _cardWaveCtrl,
          paying: phase == OledDisplayPhase.payment,
        ),
      OledDisplayPhase.dispensing => _DispensePhase(compact: widget.compact),
      OledDisplayPhase.success => _SuccessPhase(
          session: widget.session,
          compact: widget.compact,
        ),
      OledDisplayPhase.outOfService => _OutOfServicePhase(
          compact: widget.compact,
        ),
    };
  }
}

// ─── Phasen ─────────────────────────────────────────────────────────────────

