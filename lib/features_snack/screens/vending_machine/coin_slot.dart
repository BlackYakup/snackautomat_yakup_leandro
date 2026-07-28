import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';

class CoinSlot extends ConsumerStatefulWidget {
  const CoinSlot({super.key});

  @override
  ConsumerState<CoinSlot> createState() => _CoinSlotState();
}

class _CoinSlotState extends ConsumerState<CoinSlot> {
  bool _coinWasAccepted = false;

  Future<void> _insertCoin(int denominationCents) async {
    final amountBefore = ref.read(vendingSessionProvider).insertedAmountCents;

    await ref
        .read(vendingSessionProvider.notifier)
        .insertCoin(denominationCents);

    if (!mounted) {
      return;
    }

    final amountAfter = ref.read(vendingSessionProvider).insertedAmountCents;

    if (amountAfter <= amountBefore) {
      return;
    }

    setState(() {
      _coinWasAccepted = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (mounted) {
      setState(() {
        _coinWasAccepted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputEnabled = ref.watch(
      vendingSessionProvider.select((session) => session.canInsertCoins),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Münzschlitz',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DragTarget<int>(
          onWillAcceptWithDetails: (details) {
            return inputEnabled &&
                coinDenominationsCents.contains(details.data);
          },
          onAcceptWithDetails: (details) async {
            await _insertCoin(details.data);
          },
          builder: (context, candidateData, rejectedData) {
            final isHovered = inputEnabled && candidateData.isNotEmpty;

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: inputEnabled ? 1 : 0.45,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 76,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isHovered
                        ? [Colors.blueGrey.shade500, Colors.blueGrey.shade800]
                        : [Colors.grey.shade400, Colors.grey.shade700],
                  ),
                  border: Border.all(
                    color: _coinWasAccepted
                        ? Colors.greenAccent
                        : isHovered
                        ? Colors.lightBlueAccent
                        : Colors.grey.shade900,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      offset: Offset(0, 3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: isHovered ? 76 : 66,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black87,
                            offset: Offset(0, 2),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _coinWasAccepted
                          ? 'Münze angenommen'
                          : !inputEnabled
                          ? 'Bitte warten'
                          : isHovered
                          ? 'Loslassen'
                          : 'Münze hier einwerfen',
                      style: TextStyle(
                        color: _coinWasAccepted
                            ? Colors.greenAccent
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        const Text(
          'Münzen antippen oder ziehen',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          alignment: WrapAlignment.center,
          children: coinDenominationsCents.map((coin) {
            return Draggable<int>(
              data: coin,
              maxSimultaneousDrags: inputEnabled ? 1 : 0,
              feedback: Material(
                color: Colors.transparent,
                child: CoinWidget(denominationCents: coin, isDragging: true),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: CoinWidget(
                  denominationCents: coin,
                  enabled: inputEnabled,
                ),
              ),
              child: CoinWidget(
                denominationCents: coin,
                enabled: inputEnabled,
                onTap: inputEnabled ? () => _insertCoin(coin) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class CoinWidget extends StatelessWidget {
  const CoinWidget({
    super.key,
    required this.denominationCents,
    this.onTap,
    this.isDragging = false,
    this.diameter = 46,
    this.enabled = true,
  });

  final int denominationCents;
  final VoidCallback? onTap;
  final bool isDragging;
  final double diameter;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = _coinColors(denominationCents);

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Transform.scale(
          scale: isDragging ? 1.12 : 1,
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                colors: colors,
              ),
              border: Border.all(color: Colors.grey.shade800, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  offset: Offset(0, 3),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _coinLabel(denominationCents),
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: diameter <= 36 ? 9 : 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _coinColors(int denominationCents) {
    if (denominationCents <= 5) {
      return [
        Colors.orange.shade100,
        Colors.brown.shade300,
        Colors.brown.shade500,
      ];
    }

    if (denominationCents <= 50) {
      return [
        Colors.amber.shade100,
        Colors.amber.shade400,
        Colors.orange.shade600,
      ];
    }

    return [Colors.grey.shade100, Colors.grey.shade400, Colors.grey.shade700];
  }

  String _coinLabel(int denominationCents) {
    if (denominationCents < 100) {
      return '${denominationCents}ct';
    }

    return '${denominationCents ~/ 100}€';
  }
}
