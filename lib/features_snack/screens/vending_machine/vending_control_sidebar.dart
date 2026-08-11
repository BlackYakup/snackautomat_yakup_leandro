import 'dart:async';

import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/vending_control_front.dart';

/// Rechte Bedien-Sidebar: fährt aus, wenn die Maus den rechten Rand berührt.
class VendingControlSidebar extends StatefulWidget {
  const VendingControlSidebar({
    super.key,
    required this.session,
    this.width = 400,
    this.edgeHitWidth = 28,
  });

  final VendingSessionState session;
  final double width;
  final double edgeHitWidth;

  @override
  State<VendingControlSidebar> createState() => _VendingControlSidebarState();
}

class _VendingControlSidebarState extends State<VendingControlSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  bool _pinned = false;
  bool _hovering = false;
  Timer? _closeTimer;

  bool get _open => _pinned || _hovering;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.addStatusListener((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _syncOpen() {
    if (_open) {
      _closeTimer?.cancel();
      _ctrl.forward();
    } else {
      _closeTimer?.cancel();
      _closeTimer = Timer(const Duration(milliseconds: 220), () {
        if (!_open && mounted) _ctrl.reverse();
      });
    }
  }

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
    _syncOpen();
  }

  void _togglePin() {
    setState(() => _pinned = !_pinned);
    _syncOpen();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: widget.edgeHitWidth,
          child: MouseRegion(
            onEnter: (_) => _setHover(true),
            onExit: (_) => _setHover(false),
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        if (!_open)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 22,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252830).withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(10),
                    ),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, color: Colors.white70, size: 18),
                      SizedBox(height: 6),
                      RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          'Bedienung',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: _slide,
            child: IgnorePointer(
              ignoring: _ctrl.isDismissed && !_open,
              child: MouseRegion(
                onEnter: (_) => _setHover(true),
                onExit: (_) => _setHover(false),
                child: Material(
                  elevation: 12,
                  color: const Color(0xFF1E2128),
                  child: SizedBox(
                    width: widget.width,
                    height: double.infinity,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Color(0xFF3A4050), width: 1),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF242830), Color(0xFF16181E)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SidebarHeader(
                            pinned: _pinned,
                            onTogglePin: _togglePin,
                            onClose: () {
                              setState(() {
                                _pinned = false;
                                _hovering = false;
                              });
                              _syncOpen();
                            },
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              child: VendingControlFront(
                                session: widget.session,
                                dense: true,
                                showChangeSection: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.pinned,
    required this.onTogglePin,
    required this.onClose,
  });

  final bool pinned;
  final VoidCallback onTogglePin;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 2, 4),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, color: Colors.cyanAccent, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Bedienung',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: pinned ? 'Nicht mehr anheften' : 'Offen halten',
            visualDensity: VisualDensity.compact,
            onPressed: onTogglePin,
            icon: Icon(
              pinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: pinned ? Colors.cyanAccent : Colors.white54,
              size: 18,
            ),
          ),
          IconButton(
            tooltip: 'Schließen',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }
}
