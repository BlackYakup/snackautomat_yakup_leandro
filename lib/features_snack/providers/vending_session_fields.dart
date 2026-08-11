part of 'provider_library.dart';

mixin _VendingSessionFields on Notifier<VendingSessionState> {
  Timer? _slotInputTimer;
  Timer? _coinPersistTimer;
  var _coinStateLoaded = false;
  Timer? _customerFlowTimer;
  bool _autoPurchaseInProgress = false;

  /// Optional 3D fall animation before stock decrement.
  Future<void> Function(String slotCode, int visibleStock)? dispenseAnimationHandler;
}
