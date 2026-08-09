part of 'slide_widgets_library.dart';

class _FlowSlideView extends StatefulWidget {
  const _FlowSlideView({required this.slide});
  final FlowSlide slide;

  @override
  State<_FlowSlideView> createState() => _FlowSlideViewState();
}

class _FlowSlideViewState extends State<_FlowSlideView> {
  /// 0 bereit, 1 zahlung, 2 ausgabe, 3 danke
  int _phase = 0;

  FlowSlide get slide => widget.slide;

  Color _tone(FlowTone t) => switch (t) {
        FlowTone.green => const Color(0xFF2F9E6B),
        FlowTone.blue => const Color(0xFF3A7BD5),
        FlowTone.yellow => const Color(0xFFC9922A),
        FlowTone.neutral => const Color(0xFF6A7680),
      };

  ({String title, String subtitle, String led, String phaseKey, String detail})
      get _hud {
    return switch (_phase) {
      1 => (
          title: 'ZAHLUNG',
          subtitle: 'Bitte bezahlen…',
          led: '#FFD200',
          phaseKey: 'payment',
          detail:
              'Münzen/Karte: inserted steigt, missing sinkt. UI und Session sperren Slot-Wechsel.',
        ),
      2 => (
          title: 'AUSGABE…',
          subtitle: 'Bitte warten',
          led: '#00F2FE',
          phaseKey: 'dispensing',
          detail:
              'Handler: dispenseItem(slot) → Aufzug/Spirale, danach setDeliveryFlapOpen.',
        ),
      3 => (
          title: 'VIELEN DANK',
          subtitle: 'Guten Appetit',
          led: '#00FF87',
          phaseKey: 'success',
          detail: 'Kurzanzeige, dann Reset auf BEREIT. Stock wurde bereits −1.',
        ),
      _ => (
          title: 'WÄHLE DEIN PRODUKT',
          subtitle: 'Code eingeben  ·  z. B. A1',
          led: '#00F2FE',
          phaseKey: 'idle',
          detail:
              'Slot tippen (Sidebar/Keypad) setzt selectedSlotCode. Display zeigt Idle.',
        ),
    };
  }

  void _setPhase(int i) {
    final max = slide.steps.isEmpty ? 0 : slide.steps.length - 1;
    setState(() => _phase = i.clamp(0, max));
  }

  void _onTransition(String label) {
    final low = label.toLowerCase();
    if (low.contains('slot')) {
      _setPhase(0);
      return;
    }
    if (low.contains('münz') || low.contains('munz')) {
      _setPhase(1);
      return;
    }
    if (low.contains('ausgabe') || low.contains('klappe')) {
      _setPhase(2);
      return;
    }
    if (low.contains('zurück') ||
        low.contains('zuruck') ||
        low.contains('reset')) {
      _setPhase(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hud = _hud;
    final led = Color(int.parse('FF${hud.led.substring(1)}', radix: 16));
    final phaseButtons = [
      for (var i = 0; i < slide.steps.length; i++)
        (label: slide.steps[i].label, tone: slide.steps[i].tone, index: i),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Kicker(slide.kicker),
                const SizedBox(height: 8),
                Text(
                  slide.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: PresentationTheme.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  slide.caption,
                  style: const TextStyle(
                    color: PresentationTheme.muted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < phaseButtons.length; i++) ...[
                      _PhaseChip(
                        label: phaseButtons[i].label,
                        color: _tone(phaseButtons[i].tone),
                        selected: _phase == phaseButtons[i].index,
                        onTap: () => _setPhase(phaseButtons[i].index),
                      ),
                      if (i < phaseButtons.length - 1)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: PresentationTheme.muted,
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in slide.transitions)
                      ActionChip(
                        label: Text(t),
                        onPressed: () => _onTransition(t),
                        backgroundColor: Colors.white.withValues(alpha: 0.85),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  hud.detail,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: PresentationTheme.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  'Tipp: Phasen oder Chips antippen — das Display aktualisiert sich.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 5,
            child: _HudDisplayMock(
              title: hud.title,
              subtitle: hud.subtitle,
              led: led,
              slot: _phase == 0 ? '' : 'A1',
              phaseLabel: phaseButtons[_phase].label,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: selected ? 1 : 0.55),
      borderRadius: BorderRadius.circular(12),
      elevation: selected ? 3 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                selected ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _HudDisplayMock extends StatelessWidget {
  const _HudDisplayMock({
    required this.title,
    required this.subtitle,
    required this.led,
    required this.slot,
    required this.phaseLabel,
  });

  final String title;
  final String subtitle;
  final Color led;
  final String slot;
  final String phaseLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: led.withValues(alpha: 0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: led.withValues(alpha: 0.25),
            blurRadius: 18,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: led, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  'HUD / OLED  ·  $phaseLabel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (slot.isNotEmpty)
                  Text(
                    slot,
                    style: TextStyle(
                      color: led,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: led,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              'Münzen einwerfen · Preis bezahlen',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

