part of 'digital_display_library.dart';

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
