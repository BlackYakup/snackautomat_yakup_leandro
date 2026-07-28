import 'dart:async';

import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';

class DigitalDisplay extends StatefulWidget {
  const DigitalDisplay({super.key, required this.session});

  final VendingSessionState session;

  @override
  State<DigitalDisplay> createState() => _DigitalDisplayState();
}

class _DigitalDisplayState extends State<DigitalDisplay> {
  Timer? _typewriterTimer;
  String _visibleThankYouText = '';
  int _visibleCharacterCount = 0;

  @override
  void didUpdateWidget(covariant DigitalDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final enteredThankYou =
        oldWidget.session.phase != VendingMachinePhase.thankYou &&
        widget.session.phase == VendingMachinePhase.thankYou;
    final leftThankYou =
        oldWidget.session.phase == VendingMachinePhase.thankYou &&
        widget.session.phase != VendingMachinePhase.thankYou;

    if (enteredThankYou) {
      _startTypewriter();
    } else if (leftThankYou) {
      _stopTypewriter();
    }
  }

  void _startTypewriter() {
    _typewriterTimer?.cancel();
    _visibleCharacterCount = 0;

    setState(() {
      _visibleThankYouText = '';
    });

    _typewriterTimer = Timer.periodic(thankYouCharacterDuration, (timer) {
      if (!mounted || widget.session.phase != VendingMachinePhase.thankYou) {
        timer.cancel();
        return;
      }

      if (_visibleCharacterCount >= thankYouMessage.length) {
        timer.cancel();
        return;
      }

      _visibleCharacterCount += 1;

      setState(() {
        _visibleThankYouText = thankYouMessage.substring(
          0,
          _visibleCharacterCount,
        );
      });
    });
  }

  void _stopTypewriter() {
    _typewriterTimer?.cancel();
    _visibleCharacterCount = 0;
    _visibleThankYouText = '';
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final product = session.selectedProduct;
    final slotText = session.currentSlotInput.isNotEmpty
        ? session.currentSlotInput
        : session.selectedSlotCode ?? '-';
    final expectedChange = session.expectedChangeCents;
    final missingColor = product != null && session.missingAmountCents > 0
        ? Colors.orangeAccent
        : Colors.greenAccent;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade900,
              const Color(0xFF111820),
              Colors.black,
            ],
          ),
          border: Border.all(color: Colors.blueGrey.shade700, width: 2),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'monospace',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(session.phase),
              const Divider(color: Colors.white24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: session.phase == VendingMachinePhase.thankYou
                    ? _buildThankYouMessage()
                    : _buildPaymentInformation(
                        session: session,
                        product: product,
                        slotText: slotText,
                        expectedChange: expectedChange,
                        missingColor: missingColor,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(VendingMachinePhase phase) {
    final ledColor = _statusLedColor(phase);

    return Row(
      children: [
        const Icon(
          Icons.monitor_heart_outlined,
          color: Colors.cyanAccent,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          'DISPLAY',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          key: const ValueKey('status-led'),
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: ledColor,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: ledColor, blurRadius: 7)],
          ),
        ),
      ],
    );
  }

  Widget _buildThankYouMessage() {
    return SizedBox(
      key: const ValueKey('thank-you'),
      height: 170,
      child: Center(
        child: Text(
          _visibleThankYouText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            height: 1.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentInformation({
    required VendingSessionState session,
    required Product? product,
    required String slotText,
    required int? expectedChange,
    required Color missingColor,
  }) {
    return Column(
      key: const ValueKey('payment-information'),
      children: [
        _buildDisplayRow(
          label: 'Slot',
          value: slotText,
          valueColor: _slotColor(slotText),
        ),
        _buildDisplayRow(
          label: 'Produkt',
          value: product?.name ?? '-',
          valueColor: Colors.lightGreenAccent,
        ),
        _buildDisplayRow(
          label: 'Preis',
          value: product == null ? '-' : formatCents(product.priceCents),
          valueColor: Colors.white,
        ),
        _buildDisplayRow(
          label: 'Eingeworfen',
          value: formatCents(session.insertedAmountCents),
          valueColor: Colors.amberAccent,
        ),
        _buildDisplayRow(
          label: 'Fehlt',
          value: product == null
              ? '-'
              : formatCents(session.missingAmountCents),
          valueColor: missingColor,
        ),
        _buildDisplayRow(
          label: 'Wechselgeld',
          value: expectedChange == null ? '-' : formatCents(expectedChange),
          valueColor: Colors.lightBlueAccent,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _statusColor(session).withOpacity(0.12),
            border: Border.all(color: _statusColor(session).withOpacity(0.55)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            session.statusMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _statusColor(session),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayRow({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusLedColor(VendingMachinePhase phase) {
    switch (phase) {
      case VendingMachinePhase.ready:
        return Colors.greenAccent;
      case VendingMachinePhase.paymentInProgress:
        return Colors.blueAccent;
      case VendingMachinePhase.dispensing:
      case VendingMachinePhase.thankYou:
        return Colors.amberAccent;
      case VendingMachinePhase.outOfService:
        return Colors.redAccent;
    }
  }

  Color _slotColor(String slot) {
    if (slot.isEmpty || slot == '-') {
      return Colors.white54;
    }

    switch (slot[0].toUpperCase()) {
      case 'A':
      case 'B':
        return Colors.cyanAccent;
      case 'C':
        return Colors.lightBlueAccent;
      case 'D':
        return Colors.pinkAccent;
      case 'E':
        return Colors.orangeAccent;
      case 'F':
        return Colors.greenAccent;
      default:
        return Colors.white;
    }
  }

  Color _statusColor(VendingSessionState session) {
    switch (session.phase) {
      case VendingMachinePhase.paymentInProgress:
        return Colors.blueAccent;
      case VendingMachinePhase.dispensing:
      case VendingMachinePhase.thankYou:
        return Colors.amberAccent;
      case VendingMachinePhase.outOfService:
        return Colors.redAccent;
      case VendingMachinePhase.ready:
        break;
    }

    final message = session.statusMessage.toLowerCase();

    if (message.contains('kein produkt') ||
        message.contains('nicht') ||
        message.contains('ausverkauft') ||
        message.contains('ungültig')) {
      return Colors.redAccent;
    }

    return Colors.greenAccent;
  }
}
