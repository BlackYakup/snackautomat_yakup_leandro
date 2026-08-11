part of 'admin_coin_inventory_panel_library.dart';

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
                      footer: _GlobalActions(),
                      child: _DesignTable(session: session),
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
                        footer: _GlobalActions(),
                        child: _DesignTable(session: session),
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
            label: 'Physisch über Soll/Abwurf',
            value:
                '${session.totalCoinHarvestable} Stk. / ${formatCents(session.totalHarvestableValueCents)}',
          ),
          _SummaryChip(
            label: 'Eigene Münzen',
            value:
                '${session.totalCoinOwnCoins} Stk. / ${formatCents(session.totalOwnCoinValueCents)}',
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

