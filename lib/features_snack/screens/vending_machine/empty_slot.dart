import 'package:flutter/material.dart';

class EmptySlot extends StatelessWidget {
  const EmptySlot({super.key, required this.slotLabel});

  final String slotLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              slotLabel,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ),
      ),
    );
  }
}
