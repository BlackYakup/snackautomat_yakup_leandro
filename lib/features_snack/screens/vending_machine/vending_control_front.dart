import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/change_output.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/coin_slot.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/digital_display.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/slot_keypad.dart';

/// Automaten-Oberfläche für die Bedien-Sidebar (Display · Tasten · Münzen).
class VendingControlFront extends StatefulWidget {
  const VendingControlFront({
    super.key,
    required this.session,
    this.dense = false,
    this.showChangeSection = true,
    this.panelStyle = false,
  });

  final VendingSessionState session;
  final bool dense;
  final bool showChangeSection;
  final bool panelStyle;

  @override
  State<VendingControlFront> createState() => _VendingControlFrontState();
}

class _VendingControlFrontState extends State<VendingControlFront> {
  late final ExpansibleController _changeSectionController;
  var _changeSectionExpanded = false;

  @override
  void initState() {
    super.initState();
    _changeSectionController = ExpansibleController();
    _changeSectionExpanded = widget.session.hasPendingChange;
    if (_changeSectionExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _changeSectionController.expand();
      });
    }
  }

  @override
  void didUpdateWidget(covariant VendingControlFront oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasChange = widget.session.hasPendingChange;
    if (hasChange && !_changeSectionExpanded) {
      _changeSectionExpanded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _changeSectionController.expand();
      });
    } else if (!hasChange && oldWidget.session.hasPendingChange) {
      _changeSectionExpanded = false;
    }
  }

  @override
  void dispose() {
    _changeSectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dense = widget.dense;
    final panelStyle = widget.panelStyle;
    final session = widget.session;
    final gap = dense ? 6.0 : 8.0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DigitalDisplay(session: session, compact: dense),
        SizedBox(height: gap),
        _Section(
          title: 'Tastenfeld',
          dense: dense,
          panelStyle: panelStyle,
          child: SlotKeypad(dense: dense, showTitle: false),
        ),
        SizedBox(height: gap),
        _Section(
          title: 'Münzen',
          subtitle: dense
              ? 'Erst nach Produktwahl / Preis'
              : 'Antippen oder in den Schlitz ziehen — nur bei angezeigtem Preis',
          dense: dense,
          panelStyle: panelStyle,
          child: const CoinSlot(),
        ),
        if (widget.showChangeSection) ...[
          SizedBox(height: dense ? 4 : 6),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              expansionTileTheme: const ExpansionTileThemeData(
                iconColor: Colors.white54,
                collapsedIconColor: Colors.white54,
                textColor: Colors.white70,
                collapsedTextColor: Colors.white70,
              ),
            ),
            child: Material(
              color: panelStyle
                  ? const Color(0xFF1A1D24).withValues(alpha: 0.85)
                  : const Color(0xFF2A2E38),
              borderRadius: BorderRadius.circular(panelStyle ? 6 : 10),
              child: ExpansionTile(
                controller: _changeSectionController,
                initiallyExpanded: session.hasPendingChange,
                onExpansionChanged: (expanded) {
                  _changeSectionExpanded = expanded;
                },
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                title: Text(
                  session.hasPendingChange
                      ? 'Rückgeldausgabe · antippen'
                      : 'Rückgeldausgabe',
                  style: TextStyle(
                    fontSize: dense ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: session.hasPendingChange
                        ? Colors.amberAccent
                        : null,
                  ),
                ),
                children: [
                  ChangeOutput(session: session),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    if (!panelStyle) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE61C1F26), Color(0xF0121419)],
        ),
        border: Border.all(color: const Color(0xFF4A5160), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(dense ? 6 : 8),
        child: content,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.subtitle,
    this.dense = false,
    this.panelStyle = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool dense;
  final bool panelStyle;

  @override
  Widget build(BuildContext context) {
    if (panelStyle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white54,
              fontSize: dense ? 9 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: dense ? 4 : 6),
          child,
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2E38),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, dense ? 6 : 10, 10, dense ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white70,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                subtitle!,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
            SizedBox(height: dense ? 5 : 8),
            child,
          ],
        ),
      ),
    );
  }
}
