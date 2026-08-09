part of 'slide_widgets_library.dart';

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

