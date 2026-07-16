import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/coin_slot.dart';

class ChangeOutput extends StatefulWidget {
  const ChangeOutput({
    super.key,
    required this.session,
  });

  final VendingSessionState session;

  @override
  State<ChangeOutput> createState() => _ChangeOutputState();
}

class _ChangeOutputState extends State<ChangeOutput>
    with SingleTickerProviderStateMixin {
  static const _maximumVisibleCoins = 8;

  late final AnimationController _controller;
  String _lastChangeSignature = '';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: changeDropDuration,
    );
    _lastChangeSignature = _changeSignature(widget.session.outputChange);
  }

  @override
  void didUpdateWidget(covariant ChangeOutput oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newSignature = _changeSignature(widget.session.outputChange);

    if (newSignature.isEmpty) {
      _lastChangeSignature = '';
      _controller.reset();
      return;
    }

    if (newSignature != _lastChangeSignature) {
      _lastChangeSignature = newSignature;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outputChange = widget.session.outputChange;
    final allCoins = _expandCoins(outputChange);
    final visibleCoins = allCoins.take(_maximumVisibleCoins).toList();
    final hiddenCoinCount = allCoins.length - visibleCoins.length;

    return Card(
      color: Colors.grey.shade900,
      child: SizedBox(
        width: double.infinity,
        height: 120,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              const Text(
                'Wechselgeldausgabe',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: outputChange.isEmpty
                    ? const Center(
                        child: Text(
                          'Leer',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Wrap(
                            spacing: 4,
                            runSpacing: 3,
                            alignment: WrapAlignment.center,
                            children: [
                              for (var index = 0;
                                  index < visibleCoins.length;
                                  index++)
                                _buildFallingCoin(
                                  denomination: visibleCoins[index],
                                  index: index,
                                ),
                            ],
                          );
                        },
                      ),
              ),
              if (hiddenCoinCount > 0)
                Text(
                  '+ $hiddenCoinCount weitere Münzen',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 11,
                  ),
                ),
              if (outputChange.isNotEmpty)
                Text(
                  _formatCoinMap(outputChange),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallingCoin({
    required int denomination,
    required int index,
  }) {
    final start = (index * 0.07).clamp(0.0, 0.45).toDouble();
    final end = (start + 0.55).clamp(0.0, 1.0).toDouble();
    final intervalProgress =
        ((_controller.value - start) / (end - start))
            .clamp(0.0, 1.0)
            .toDouble();
    final progress = Curves.bounceOut.transform(intervalProgress);

    return Transform.translate(
      offset: Offset(0, -48 * (1 - progress)),
      child: Opacity(
        opacity: progress,
        child: CoinWidget(
          denominationCents: denomination,
          diameter: 34,
        ),
      ),
    );
  }

  List<int> _expandCoins(Map<int, int> coins) {
    final entries = coins.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final result = <int>[];

    for (final entry in entries) {
      for (var index = 0; index < entry.value; index++) {
        result.add(entry.key);
      }
    }

    return result;
  }

  String _changeSignature(Map<int, int> coins) {
    if (coins.isEmpty) {
      return '';
    }

    final entries = coins.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join('|');
  }

  String _formatCoinMap(Map<int, int> coins) {
    final entries = coins.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return entries
        .map((entry) => '${entry.value} x ${formatCents(entry.key)}')
        .join(', ');
  }
}
