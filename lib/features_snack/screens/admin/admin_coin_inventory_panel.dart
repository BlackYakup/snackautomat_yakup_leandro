import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/coin_asset_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_coin_visual.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';

class AdminCoinInventoryPanel extends ConsumerStatefulWidget {
  const AdminCoinInventoryPanel({super.key});

  @override
  ConsumerState<AdminCoinInventoryPanel> createState() =>
      _AdminCoinInventoryPanelState();
}

class _AdminCoinInventoryPanelState
    extends ConsumerState<AdminCoinInventoryPanel> {
  final Map<int, TextEditingController> _manualControllers = {};
  final Map<int, TextEditingController> _targetControllers = {};

  @override
  void dispose() {
    for (final controller in _manualControllers.values) {
      controller.dispose();
    }
    for (final controller in _targetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _manualControllerFor(int denomination) {
    return _manualControllers.putIfAbsent(
      denomination,
      TextEditingController.new,
    );
  }

  TextEditingController _targetControllerFor(
    int denomination,
    VendingSessionState session,
  ) {
    return _targetControllers.putIfAbsent(
      denomination,
      () => TextEditingController(
        text: '${session.coinTargetStock[denomination] ?? 0}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(vendingSessionProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryStrip(session: session),
          const SizedBox(height: 12),
          _AdminPanelCard(
            title: 'Geldkassette & Auffüllen',
            child: _CassetteTable(
              session: session,
              manualControllerFor: _manualControllerFor,
              targetControllerFor: (denomination) =>
                  _targetControllerFor(denomination, session),
              onAddManual: (denomination) {
                final amount =
                    int.tryParse(_manualControllerFor(denomination).text) ?? 0;
                if (amount <= 0) {
                  return;
                }
                ref
                    .read(vendingSessionProvider.notifier)
                    .addCoinsToInventory(denomination, amount);
                _manualControllerFor(denomination).clear();
              },
              onTargetChanged: (denomination, value) {
                final target = int.tryParse(value) ?? 0;
                ref
                    .read(vendingSessionProvider.notifier)
                    .setCoinTargetStock(denomination, target);
              },
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;

              if (stacked) {
                return Column(
                  children: [
                    _AdminPanelCard(
                      title: 'Abschöpfung & Überschuss',
                      child: _SkimTable(session: session),
                    ),
                    const SizedBox(height: 12),
                    _AdminPanelCard(
                      title: 'Münz-Design',
                      child: _DesignTable(session: session),
                      footer: _GlobalActions(),
                    ),
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _AdminPanelCard(
                        title: 'Abschöpfung & Überschuss',
                        child: _SkimTable(session: session),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _AdminPanelCard(
                        title: 'Münz-Design',
                        child: _DesignTable(session: session),
                        footer: _GlobalActions(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.session});

  final VendingSessionState session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          _SummaryChip(
            label: 'Kassette (Ist)',
            value: formatCents(session.totalCassetteValueCents),
          ),
          _SummaryChip(
            label: 'Abschöpfbar',
            value:
                '${session.totalCoinHarvestable} Stk. / ${formatCents(session.totalHarvestableValueCents)}',
          ),
          _SummaryChip(
            label: 'Erwirtschaftet',
            value:
                '${session.totalCoinEarnedSurplus} Stk. / ${formatCents(session.totalEarnedSurplusValueCents)}',
          ),
          _SummaryChip(
            label: 'Summe insgesamt',
            value: formatCents(session.totalMachineValueCents),
            highlighted: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: highlighted ? AdminColors.accent : AdminColors.textPrimary,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPanelCard extends StatelessWidget {
  const _AdminPanelCard({
    required this.title,
    required this.child,
    this.footer,
  });

  final String title;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            child: child,
          ),
          ?footer,
        ],
      ),
    );
  }
}

class _CassetteTable extends ConsumerWidget {
  const _CassetteTable({
    required this.session,
    required this.manualControllerFor,
    required this.targetControllerFor,
    required this.onAddManual,
    required this.onTargetChanged,
  });

  final VendingSessionState session;
  final TextEditingController Function(int) manualControllerFor;
  final TextEditingController Function(int) targetControllerFor;
  final void Function(int denomination) onAddManual;
  final void Function(int denomination, String value) onTargetChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(40),
        1: FlexColumnWidth(0.9),
        2: FlexColumnWidth(0.7),
        3: FlexColumnWidth(0.7),
        4: FlexColumnWidth(0.8),
        5: FlexColumnWidth(1.4),
        6: FlexColumnWidth(1.2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        const TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AdminColors.border)),
          ),
          children: [
            _TableHeaderCell(''),
            _TableHeaderCell('Wert'),
            _TableHeaderCell('Ist'),
            _TableHeaderCell('Soll'),
            _TableHeaderCell('Summe'),
            _TableHeaderCell('Aktion'),
            _TableHeaderCell('Manuell'),
          ],
        ),
        ...coinDenominationsCents.map((denomination) {
          final ist = session.coinInventory[denomination] ?? 0;
          final soll = session.coinTargetStock[denomination] ?? 0;
          final harvestable = session.coinHarvestableQuantity(denomination);
          final rowTotal = session.coinRowTotalCents(denomination);
          final imagePath = session.coinDesignPaths[denomination];
          final delta = ist - soll;

          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: CoinVisual(
                  denominationCents: denomination,
                  imagePath: imagePath,
                  size: 30,
                ),
              ),
              _TableDataCell(coinValueLabel(denomination)),
              _TableDataCell(
                '$ist',
                color: delta < 0
                    ? AdminColors.danger
                    : delta > 0
                    ? AdminColors.success
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: SizedBox(
                  height: 30,
                  width: 52,
                  child: TextField(
                    controller: targetControllerFor(denomination),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                    ),
                    onSubmitted: (value) =>
                        onTargetChanged(denomination, value),
                    onEditingComplete: () => onTargetChanged(
                      denomination,
                      targetControllerFor(denomination).text,
                    ),
                  ),
                ),
              ),
              _TableDataCell(
                formatCents(rowTotal),
                subtext: harvestable > 0
                    ? '+${formatCents(denomination * harvestable)} abschöpfbar'
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _MiniButton(
                      label: '+1',
                      onPressed: () => ref
                          .read(vendingSessionProvider.notifier)
                          .addCoinsToInventory(denomination, 1),
                    ),
                    _MiniButton(
                      label: '-1',
                      onPressed: ist == 0
                          ? null
                          : () => ref
                                .read(vendingSessionProvider.notifier)
                                .removeCoinsFromInventory(denomination, 1),
                    ),
                    _MiniTextButton(
                      label: 'Leeren',
                      onPressed: ist == 0
                          ? null
                          : () => ref
                                .read(vendingSessionProvider.notifier)
                                .emptyCoinCassette(denomination),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: TextField(
                          controller: manualControllerFor(denomination),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: 'Anz.',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _MiniButton(
                      label: '+',
                      onPressed: () => onAddManual(denomination),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _SkimTable extends ConsumerWidget {
  const _SkimTable({required this.session});

  final VendingSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(0.8),
            2: FlexColumnWidth(0.8),
            3: FlexColumnWidth(0.9),
            4: FlexColumnWidth(1),
            5: FlexColumnWidth(0.9),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AdminColors.border)),
              ),
              children: [
                _TableHeaderCell('Münze'),
                _TableHeaderCell('Ist Kassette'),
                _TableHeaderCell('Abschöpfbar'),
                _TableHeaderCell('Erwirtschaftet'),
                _TableHeaderCell('Summe'),
                _TableHeaderCell('Abschöpfen'),
              ],
            ),
            ...coinDenominationsCents.map((denomination) {
              final ist = session.coinInventory[denomination] ?? 0;
              final harvestable = session.coinHarvestableQuantity(denomination);
              final earned = session.coinEarnedSurplus[denomination] ?? 0;
              final rowTotal = session.coinRowTotalCents(denomination);

              return TableRow(
                children: [
                  _TableDataCell(coinValueLabel(denomination)),
                  _TableDataCell('$ist Stk.'),
                  _TableDataCell(
                    '$harvestable Stk.',
                    color: harvestable > 0 ? AdminColors.warning : null,
                  ),
                  _TableDataCell(
                    '$earned Stk.',
                    color: earned > 0 ? AdminColors.success : null,
                  ),
                  _TableDataCell(formatCents(rowTotal)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 4,
                    ),
                    child: _MiniButton(
                      label: 'Abschöpfen',
                      onPressed: harvestable == 0
                          ? null
                          : () => ref
                                .read(vendingSessionProvider.notifier)
                                .skimCoinSurplus(denomination),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AdminColors.surfaceHighlight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.border),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _FooterStat(
                label: 'Kassette',
                value: formatCents(session.totalCassetteValueCents),
              ),
              _FooterStat(
                label: 'Abschöpfbar',
                value:
                    '${session.totalCoinHarvestable} Stk. / ${formatCents(session.totalHarvestableValueCents)}',
              ),
              _FooterStat(
                label: 'Erwirtschaftet',
                value:
                    '${session.totalCoinEarnedSurplus} Stk. / ${formatCents(session.totalEarnedSurplusValueCents)}',
              ),
              _FooterStat(
                label: 'Gesamt im Automaten',
                value: formatCents(session.totalMachineValueCents),
              ),
              _FooterStat(
                label: 'Abwürfe',
                value: '${session.changeDispenseCount}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesignTable extends ConsumerWidget {
  const _DesignTable({required this.session});

  final VendingSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.8),
        1: FixedColumnWidth(40),
        2: FlexColumnWidth(1.4),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        const TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AdminColors.border)),
          ),
          children: [
            _TableHeaderCell('Wert'),
            _TableHeaderCell(''),
            _TableHeaderCell('Upload'),
          ],
        ),
        ...coinDenominationsCents.map((denomination) {
          final imagePath = session.coinDesignPaths[denomination];

          return TableRow(
            children: [
              _TableDataCell(coinValueLabel(denomination)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: CoinVisual(
                  denominationCents: denomination,
                  imagePath: imagePath,
                  size: 28,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: _MiniButton(
                  label: 'Design',
                  onPressed: () => _pickDesign(ref, denomination),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _pickDesign(WidgetRef ref, int denomination) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    final path = result?.files.single.path;

    if (path == null) {
      return;
    }

    try {
      final persistedPath = await CoinAssetStorage.persistDesignPath(path);

      ref
          .read(vendingSessionProvider.notifier)
          .setCoinDesignPath(denomination, persistedPath);
    } catch (error) {
      debugPrint('Münz-Design speichern fehlgeschlagen: $error');
    }
  }
}

class _GlobalActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vendingSessionProvider.notifier);
    final session = ref.watch(vendingSessionProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          const Text(
            'Global:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AdminColors.textMuted,
            ),
          ),
          const Spacer(),
          _MiniTextButton(
            label: 'Kassette leeren',
            onPressed: notifier.emptyAllCoinCassettes,
          ),
          const SizedBox(width: 6),
          _MiniTextButton(
            label: 'Überschuss abschöpfen',
            onPressed: session.totalCoinHarvestable == 0
                ? null
                : notifier.skimAllCoinSurplus,
          ),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AdminColors.textPrimary,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TableDataCell extends StatelessWidget {
  const _TableDataCell(this.text, {this.subtext, this.color});

  final String text;
  final String? subtext;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: color ?? AdminColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtext != null)
            Text(
              subtext!,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 28),
          textStyle: const TextStyle(fontSize: 11),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label),
      ),
    );
  }
}

class _MiniTextButton extends StatelessWidget {
  const _MiniTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 28),
        textStyle: const TextStyle(fontSize: 11),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: AdminColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
