import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';

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

class _IdlePhase extends StatelessWidget {
  const _IdlePhase({
    required this.pulse,
    required this.compact,
    required this.statusMessage,
  });

  final AnimationController pulse;
  final bool compact;
  final String statusMessage;

  bool get _isAlert {
    final m = statusMessage.toLowerCase();
    return m.contains('leer') ||
        m.contains('ausverkauft') ||
        m.contains('ungültig') ||
        m.contains('unvollständig');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 110 : 150,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.55, end: 1).animate(pulse),
            child: Text(
              'WÄHLE DEIN PRODUKT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 16 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                height: 1.15,
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          if (_isAlert)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFFF4D6D),
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            )
          else ...[
            FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 0.9).animate(pulse),
              child: Text(
                'Code eingeben  ·  z. B. A1',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.85),
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              'Münzen einwerfen · Preis bezahlen',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF8B949E),
                fontSize: compact ? 10 : 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingPhase extends StatelessWidget {
  const _TypingPhase({required this.input, required this.compact});

  final String input;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 110 : 150,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'SLOT',
            style: TextStyle(
              color: const Color(0xFF00F2FE).withValues(alpha: 0.7),
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            input,
            style: TextStyle(
              color: const Color(0xFF00FF87),
              fontSize: compact ? 36 : 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              height: 1,
              shadows: [
                Shadow(
                  color: const Color(0xFF00FF87).withValues(alpha: 0.45),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            input.length >= 2
                ? 'Prüfe in 3 Sek.  ·  oder weiter tippen'
                : 'Produktcode fortsetzen…',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPayPhase extends StatelessWidget {
  const _SelectedPayPhase({
    required this.session,
    required this.compact,
    required this.cardWave,
    required this.paying,
  });

  final VendingSessionState session;
  final bool compact;
  final AnimationController cardWave;
  final bool paying;

  @override
  Widget build(BuildContext context) {
    final product = session.selectedProduct;
    final slot = session.selectedSlotCode ?? session.currentSlotInput;
    final remaining = product == null
        ? 0
        : session.missingAmountCents.clamp(0, product.priceCents);
    final price = product?.priceCents ?? 0;
    final inserted = session.insertedAmountCents;
    final progress = price <= 0 ? 0.0 : (inserted / price).clamp(0.0, 1.0);
    final isDrink = product?.category == ProductCategory.drinks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CategoryIcon(isDrink: isDrink, compact: compact),
            SizedBox(width: compact ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$slot  ·  ${product?.name ?? '—'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  Text(
                    paying ? 'NOCH ZU BEZAHLEN' : 'PREIS',
                    style: TextStyle(
                      color: const Color(0xFF8B949E),
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  _AnimatedEuro(
                    cents: paying ? remaining : price,
                    color: paying
                        ? const Color(0xFFFFD200)
                        : const Color(0xFF00FF87),
                    compact: compact,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (paying) ...[
          SizedBox(height: compact ? 10 : 14),
          _NeonProgress(value: progress, compact: compact),
          SizedBox(height: compact ? 6 : 8),
          Row(
            children: [
              Text(
                'Eingeworfen ${formatCents(inserted)}',
                style: TextStyle(
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.85),
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Rest ${formatCents(remaining)}',
                style: TextStyle(
                  color: const Color(0xFFFFD200).withValues(alpha: 0.95),
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: compact ? 10 : 14),
        FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(cardWave),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.contactless,
                size: compact ? 16 : 18,
                color: const Color(0xFF00F2FE),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  paying
                      ? 'Münzen einwerfen bis Preis erreicht'
                      : 'Mit Münzen bezahlen · X = Abbrechen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF00F2FE),
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DispensePhase extends StatelessWidget {
  const _DispensePhase({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 110 : 150,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'PRODUKT WIRD AUSGEGEBEN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF00F2FE),
              fontSize: compact ? 14 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          const Text(
            'Spirale dreht  ·  bitte warten',
            style: TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 14 : 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: compact ? 4 : 5,
              backgroundColor: const Color(0xFF21262D),
              color: const Color(0xFF00F2FE),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessPhase extends StatelessWidget {
  const _SuccessPhase({required this.session, required this.compact});

  final VendingSessionState session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final changeCents = session.outputChange.entries.fold<int>(
      0,
      (sum, e) => sum + e.key * e.value,
    );

    return SizedBox(
      height: compact ? 110 : 150,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'GUTEN APPETIT!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF00FF87),
              fontSize: compact ? 20 : 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              shadows: [
                Shadow(
                  color: const Color(0xFF00FF87).withValues(alpha: 0.5),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          if (changeCents > 0)
            Text(
              'Rückgeld entnehmen: ${formatCents(changeCents)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFFD200),
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              'Bitte Produkt entnehmen',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF8B949E),
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _OutOfServicePhase extends StatelessWidget {
  const _OutOfServicePhase({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 110 : 150,
      child: Center(
        child: Text(
          'AUSSER BETRIEB',
          style: TextStyle(
            color: const Color(0xFFFF4D6D),
            fontSize: compact ? 16 : 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

// ─── Bausteine ──────────────────────────────────────────────────────────────

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.isDrink, required this.compact});

  final bool isDrink;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 48.0 : 64.0;
    final color = isDrink ? const Color(0xFF00F2FE) : const Color(0xFFFFD200);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14),
        ],
      ),
      child: Icon(
        isDrink ? Icons.local_drink_rounded : Icons.cookie_rounded,
        color: color,
        size: size * 0.52,
      ),
    );
  }
}

class _AnimatedEuro extends StatefulWidget {
  const _AnimatedEuro({
    required this.cents,
    required this.color,
    required this.compact,
  });

  final int cents;
  final Color color;
  final bool compact;

  @override
  State<_AnimatedEuro> createState() => _AnimatedEuroState();
}

class _AnimatedEuroState extends State<_AnimatedEuro> {
  late double _from;

  @override
  void initState() {
    super.initState();
    _from = widget.cents / 100.0;
  }

  @override
  void didUpdateWidget(covariant _AnimatedEuro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cents != widget.cents) {
      _from = oldWidget.cents / 100.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.cents),
      tween: Tween(begin: _from, end: widget.cents / 100.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final text = '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
        return Text(
          text,
          style: TextStyle(
            color: widget.color,
            fontSize: widget.compact ? 26 : 34,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: 0.4,
            shadows: [
              Shadow(
                color: widget.color.withValues(alpha: 0.45),
                blurRadius: 14,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NeonProgress extends StatelessWidget {
  const _NeonProgress({required this.value, required this.compact});

  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) {
          return LinearProgressIndicator(
            value: v,
            minHeight: compact ? 5 : 7,
            backgroundColor: const Color(0xFF21262D),
            color: const Color(0xFF00FF87),
          );
        },
      ),
    );
  }
}
