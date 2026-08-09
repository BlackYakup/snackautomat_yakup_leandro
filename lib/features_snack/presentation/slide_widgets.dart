import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/slides.dart';

class PresentationTheme {
  static const ink = Color(0xFF1A2228);
  static const muted = Color(0xFF5A6A75);
  static const accent = Color(0xFF1F8F84);
  static const card = Color(0xF2FFFFFF);
  static const stage = Color(0xFFE8EEF2);

  /// Feste Design-Auflösung der Folie (16:9).
  /// Alles skaliert proportional — Sidebar darf Layout nicht stauchen.
  static const slideDesignWidth = 1600.0;
  static const slideDesignHeight = 900.0;
}

/// Skaliert die Folie immer proportional in den verfügbaren Platz.
class SlideStage extends StatelessWidget {
  const SlideStage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: PresentationTheme.slideDesignWidth,
              height: PresentationTheme.slideDesignHeight,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.noScaling,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PresentationTheme.card,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SlideView extends StatelessWidget {
  const SlideView({super.key, required this.slide});

  final PresentationSlide slide;

  @override
  Widget build(BuildContext context) {
    return switch (slide) {
      TitleSlide s => _TitleSlideView(slide: s),
      ExplainSlide s => _ExplainSlideView(slide: s),
      DiagramSlide s => _DiagramSlideView(slide: s),
      FlowSlide s => _FlowSlideView(slide: s),
      CodeSlide s => _CodeSlideView(slide: s),
      StatusSlide s => _StatusSlideView(slide: s),
      ClosingSlide s => _ClosingSlideView(slide: s),
    };
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: PresentationTheme.accent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _TitleSlideView extends StatelessWidget {
  const _TitleSlideView({required this.slide});
  final TitleSlide slide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/presentation/brand/facet-emblem.png',
              width: 88,
              height: 88,
              errorBuilder: (_, _, _) => const Icon(Icons.view_in_ar, size: 72),
            ),
            const SizedBox(height: 28),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: PresentationTheme.ink,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              slide.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                color: PresentationTheme.muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              slide.meta,
              style: const TextStyle(
                fontSize: 14,
                color: PresentationTheme.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplainSlideView extends StatelessWidget {
  const _ExplainSlideView({required this.slide});
  final ExplainSlide slide;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: slide.imageAsset == null ? 1 : 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 36, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Kicker(slide.kicker),
                const SizedBox(height: 12),
                Text(
                  slide.title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: PresentationTheme.ink,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 24),
                ...slide.points.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('·  ',
                            style: TextStyle(
                              fontSize: 20,
                              color: PresentationTheme.accent,
                              fontWeight: FontWeight.w800,
                            )),
                        Expanded(
                          child: Text(
                            p,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.4,
                              color: PresentationTheme.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (slide.imageAsset != null)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 28, 36, 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(slide.imageAsset!, fit: BoxFit.contain),
              ),
            ),
          ),
      ],
    );
  }
}

class _DiagramSlideView extends StatelessWidget {
  const _DiagramSlideView({required this.slide});
  final DiagramSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 28, 36, 20),
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
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(slide.imageAsset, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.caption,
            style: const TextStyle(
              fontSize: 14,
              color: PresentationTheme.muted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _CodeSlideView extends StatelessWidget {
  const _CodeSlideView({required this.slide});
  final CodeSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Kicker(slide.kicker),
                const SizedBox(height: 6),
                Text(
                  slide.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: PresentationTheme.ink,
                    height: 1.15,
                  ),
                ),
                if (slide.summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: PresentationTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PresentationTheme.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: PresentationTheme.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            slide.summary,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: PresentationTheme.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const _SectionLabel(
                  icon: Icons.folder_open,
                  label: 'Datei im Projekt (Root)',
                ),
                const SizedBox(height: 4),
                SelectableText(
                  slide.file,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: PresentationTheme.ink,
                    fontFamily: 'Consolas',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionLabel(
                  icon: Icons.menu_book_outlined,
                  label: 'In einfachen Worten',
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: slide.explanation.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: PresentationTheme.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              slide.explanation[i],
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: PresentationTheme.ink,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in slide.tags)
                      Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: PresentationTheme.accent.withValues(
                          alpha: 0.12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF151A1F),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.code,
                          size: 16,
                          color: Color(0xFF7DDBD0),
                        ),
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
                          child: Text(
                            slide.file,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10.5,
                              fontFamily: 'Consolas',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: SelectableText(
                        slide.code.join('\n'),
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 12.5,
                          height: 1.45,
                          color: Color(0xFFE8EEF2),
                        ),
                      ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: PresentationTheme.accent),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: PresentationTheme.accent,
          ),
        ),
      ],
    );
  }
}

class _StatusSlideView extends StatelessWidget {
  const _StatusSlideView({required this.slide});
  final StatusSlide slide;

  @override
  Widget build(BuildContext context) {
    Widget col(String title, List<StatusItem> items, Color accent) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final it = items[i];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (it.imageAsset != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              it.imageAsset!,
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
                                it.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: PresentationTheme.ink,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                it.detail,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: PresentationTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 28, 36, 20),
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
            slide.intro,
            style: const TextStyle(color: PresentationTheme.muted, fontSize: 14),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                col('IST', slide.now, PresentationTheme.accent),
                const SizedBox(width: 18),
                col('SOLL', slide.next, const Color(0xFFC9922A)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosingSlideView extends StatelessWidget {
  const _ClosingSlideView({required this.slide});
  final ClosingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slide.title,
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                color: PresentationTheme.ink,
              ),
            ),
            const SizedBox(height: 28),
            ...slide.lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.4,
                    color: PresentationTheme.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
