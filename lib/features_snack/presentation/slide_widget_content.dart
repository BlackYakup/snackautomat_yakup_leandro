part of 'slide_widgets_library.dart';

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

