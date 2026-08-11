part of 'provider_library.dart';

class VendingSessionNotifier extends Notifier<VendingSessionState>
    with
        _VendingSessionFields,
        _VendingSessionCoinPersist,
        _VendingSessionHelpers,
        _VendingSessionSlotInput,
        _VendingSessionPayment,
        _VendingSessionCoinAdmin {
  @override
  VendingSessionState build() {
    ref.onDispose(() {
      _slotInputTimer?.cancel();
      _coinPersistTimer?.cancel();
      _customerFlowTimer?.cancel();
    });

    Future.microtask(_loadPersistedCoinState);

    return const VendingSessionState();
  }
}
