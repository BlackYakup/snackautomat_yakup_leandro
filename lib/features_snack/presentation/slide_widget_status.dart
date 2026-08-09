part of 'slide_widgets_library.dart';

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
