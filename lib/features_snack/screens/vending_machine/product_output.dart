import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';

class ProductOutput extends StatefulWidget {
  const ProductOutput({super.key, required this.session});

  final VendingSessionState session;

  @override
  State<ProductOutput> createState() => _ProductOutputState();
}

class _ProductOutputState extends State<ProductOutput>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  bool _isDispensing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _isDispensing = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductOutput oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldProductName = oldWidget.session.outputProductName;
    final newProductName = widget.session.outputProductName;
    final enteredDispensing =
        oldWidget.session.phase != VendingMachinePhase.dispensing &&
        widget.session.phase == VendingMachinePhase.dispensing;
    final productBecameAvailable =
        oldProductName == null && newProductName != null;

    if ((enteredDispensing || productBecameAvailable) &&
        newProductName != null) {
      setState(() {
        _isDispensing = true;
      });

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
    final productName = widget.session.outputProductName;

    return Card(
      color: Colors.grey.shade900,
      child: SizedBox(
        height: 96,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              const Text(
                "Produktausgabe",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: productName == null
                    ? const Center(
                        child: Text(
                          "Leer",
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : AnimatedBuilder(
                        animation: _progress,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2, color: Colors.amber),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        builder: (context, child) {
                          final progress = _progress.value;

                          final horizontalMovement =
                              math.sin(progress * math.pi * 4) *
                              (1 - progress) *
                              18;

                          final verticalMovement = -28 + (28 * progress);
                          final rotation = (1 - progress) * math.pi * 2;
                          final scale = 0.55 + (0.45 * progress);

                          return Transform.translate(
                            offset: Offset(
                              horizontalMovement,
                              verticalMovement,
                            ),
                            child: Transform.rotate(
                              angle: rotation,
                              child: Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: 0.35 + (0.65 * progress),
                                  child: child,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Text(
                _isDispensing ? "Produkt wird transportiert..." : "Bereit",
                style: TextStyle(
                  color: _isDispensing
                      ? Colors.amberAccent
                      : Colors.greenAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
