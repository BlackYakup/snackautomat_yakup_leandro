import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:power3d/power3d.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/admin_access.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/presentation_access.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/vending_control_sidebar.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/vending_machine/vending_machine_screen.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/power3d_bootstrap.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/vending_stock_sync.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';

/// Startbildschirm: 3D-Automat + Bedienung in der rechten Sidebar.
class VendingMachine3DLandingScreen extends ConsumerStatefulWidget {
  const VendingMachine3DLandingScreen({super.key});

  static const modelAsset = 'assets/models/vending_machine_front.glb';

  @override
  ConsumerState<VendingMachine3DLandingScreen> createState() =>
      _VendingMachine3DLandingScreenState();
}

class _VendingMachine3DLandingScreenState
    extends ConsumerState<VendingMachine3DLandingScreen> {
  Power3DController? _controller;
  bool _bootstrapped = false;
  bool _slotAcquired = false;
  bool _blocked = false;
  bool _cameraReady = false;
  /// Setup läuft: 3D noch verdeckt, API-Aufrufe aber erlaubt.
  bool _aligning = false;
  bool _opening2d = false;
  bool _openingAdmin = false;
  bool _openingPresentation = false;
  bool _orbitLocked = false;
  final String _materialStyleId = 'blender_dark';
  String? _error;
  String? _statusText;

  bool _scenePanning = false;
  Offset? _scenePanLast;
  int? _scenePanPointer;
  bool _flapOpen = false;
  bool _flapHover = false;
  bool _awaitingProductCollect = false;
  Timer? _flapHoverDebounce;
  static const _panStartSlop = 5.0;
  static const _panMaxStep = 18.0;
  static const _panTeleport = 160.0;

  static const _cameraViews = <({String id, String label, bool lockByDefault})>[
    (id: 'front', label: 'Front (2D / Ortho)', lockByDefault: true),
    (id: 'front3d', label: '3D Front', lockByDefault: false),
    (id: 'buy', label: 'Buy (Tastenfeld & Münzen)', lockByDefault: true),
    (id: 'product', label: 'Product View', lockByDefault: true),
    (id: 'dispense', label: 'Produktausgabe', lockByDefault: true),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      setState(() {
        _blocked = false;
        _error = null;
        _statusText = '3D-Viewer vorbereiten…';
      });
      // Bestand früh laden, damit Slot-Wahl nicht „leer“ bei Wettlauf meldet.
      unawaited(ref.read(productControllerProvider.future));
      unawaited(ref.read(placedProductsProvider.future));
      await Power3dBootstrap.ensureReady();
      // GLB neben der Ansicht zwischenspeichern — Dateiladen statt ~85 MB Base64 über JS-Bridge.
      await Power3DAssetManager.ensureAssetModelUrl(
        VendingMachine3DLandingScreen.modelAsset,
      );
      if (!mounted) return;
      if (!ProductModelViewerLock.tryAcquire()) {
        setState(() => _blocked = true);
        return;
      }
      _slotAcquired = true;
      _controller = Power3DController()..addListener(_onControllerChanged);
      setState(() {
        _bootstrapped = true;
        _statusText = 'Automaten-Modell laden…';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _onControllerChanged() {
    if (!mounted || _controller == null) return;
    final state = _controller!.value;
    final err = state.errorMessage;
    if (state.status == Power3DStatus.error && err != null) {
      setState(() => _error = err);
      return;
    }
    if (state.status == Power3DStatus.loading) {
      setState(() => _statusText = 'Automaten-Modell laden…');
    } else if (state.status == Power3DStatus.loaded && !_cameraReady) {
      // WebView nicht freigeben — Overlay bleibt bis Kamera fertig ist.
      setState(() => _statusText ??= 'Ansicht ausrichten…');
    }
  }

  Future<void> _onModelLoaded() async {
    if (_cameraReady || _aligning || _controller == null) return;
    _aligning = true;
    if (mounted) {
      setState(() => _statusText = 'Ansicht ausrichten…');
    }
    try {
      // Schneller Erst-Pfad: Helfer + Studio-Licht + Material einmalig,
      // Kamera setzen, UI freigeben — Stabilize/Stock danach nachziehen.
      await _controller!.ensureVendingPresentation(
        stabilize: false,
        applyMaterials: true,
        forceHelpers: true,
      );
      await _applyCameraView('front', forceLock: true);
      await _controller!.setOrbitLock(true);
      await _controller!.updateZoomSensitivity(0.55);
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _aligning = false;
        _orbitLocked = true;
        _statusText = null;
      });
      unawaited(_finishModelSetup());
    } catch (e) {
      debugPrint('3D camera/lights setup: $e');
      if (mounted) {
        setState(() {
          _cameraReady = true;
          _aligning = false;
          _statusText = null;
        });
      }
      unawaited(_finishModelSetup());
    }
  }

  /// Nach dem ersten Frame: Shelf stabilisieren, Elevator, Stock, HUD.
  Future<void> _finishModelSetup() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.ensureProjectionHelpers();
      await c.stabilizeVendingShelf();
      await c.resetElevatorHome();
      _bindDispenseHandler();
      await _syncStockFromProvider();
      if (!mounted) return;
      await _syncHudOled(ref.read(vendingSessionProvider));
    } catch (e) {
      debugPrint('3D post-load setup: $e');
    }
  }

  Future<void> _syncHudOled(VendingSessionState session) async {
    final c = _controller;
    if (c == null || (!_cameraReady && !_aligning)) return;
    final phase = switch (session.phase) {
      VendingMachinePhase.outOfService => 'outOfService',
      VendingMachinePhase.dispensing => 'dispensing',
      VendingMachinePhase.thankYou => 'success',
      VendingMachinePhase.paymentInProgress => 'payment',
      VendingMachinePhase.ready => session.selectedProduct != null
          ? 'selected'
          : (session.currentSlotInput.isNotEmpty ? 'typing' : 'idle'),
    };
    final product = session.selectedProduct;
    final slot = session.currentSlotInput.isNotEmpty
        ? session.currentSlotInput
        : (session.selectedSlotCode ?? '');
    final led = switch (phase) {
      'idle' || 'typing' || 'dispensing' => '#00F2FE',
      'selected' || 'payment' => '#FFD200',
      'success' => '#00FF87',
      'outOfService' => '#FF4D6D',
      _ => '#00F2FE',
    };
    final payload = <String, dynamic>{
      'phase': phase,
      'led': led,
      'slot': slot,
      'product': product?.name ?? '',
      'price': product == null ? '' : formatCents(product.priceCents),
      'inserted': formatCents(session.insertedAmountCents),
      'missing': product == null
          ? ''
          : formatCents(session.missingAmountCents.clamp(0, product.priceCents)),
      'status': session.statusMessage,
      'title': switch (phase) {
        'idle' => 'WÄHLE DEIN PRODUKT',
        'typing' => 'SLOT',
        'selected' => product?.name ?? 'PRODUKT',
        'payment' => 'ZAHLUNG',
        'dispensing' => 'AUSGABE…',
        'success' => 'VIELEN DANK',
        'outOfService' => 'AUSSER BETRIEB',
        _ => 'WÄHLE DEIN PRODUKT',
      },
      'subtitle': switch (phase) {
        'idle' => 'Code eingeben  ·  z. B. A1',
        'typing' => slot.length >= 2
            ? 'Prüfe in 3 Sek.  ·  oder weiter tippen'
            : 'Produktcode fortsetzen…',
        'selected' => 'Münzen einwerfen oder Karte',
        'payment' => 'Bitte bezahlen…',
        'dispensing' => 'Bitte warten',
        'success' => session.statusMessage,
        'outOfService' => session.statusMessage,
        _ => '',
      },
      'footer': 'Münzen einwerfen · Preis bezahlen',
    };
    try {
      await c.updateVendingHudOled(payload);
    } catch (e) {
      debugPrint('HUD OLED sync: $e');
    }
  }

  void _bindDispenseHandler() {
    ref.read(vendingSessionProvider.notifier).dispenseAnimationHandler =
        (slotCode, visibleStock) async {
      final c = _controller;
      if (c == null || !_cameraReady) {
        debugPrint(
          'dispenseItem übersprungen: controller=${c != null} ready=$_cameraReady',
        );
        return;
      }
      try {
        debugPrint('3D dispenseItem($slotCode, stock=$visibleStock)');
        // Kamera unverändert lassen — nur Aufzug-/Produkt-Animation.
        if (mounted) setState(() => _awaitingProductCollect = true);
        final ok = await c.dispenseItem(
          slotCode,
          visibleStock: visibleStock,
          durationMs: 5600,
        );
        debugPrint('3D dispenseItem Ergebnis: $ok');
        // PUSH hat in der 3D-Sequenz bereits 3× geblinkt — Klappe öffnen zum Entnehmen.
        await c.setDeliveryFlapOpen(true, angleDeg: 36);
        if (mounted) setState(() => _flapOpen = true);
      } catch (e) {
        debugPrint('dispenseItem: $e');
      }
    };
  }

  void _clearDispenseHandler() {
    final n = ref.read(vendingSessionProvider.notifier);
    if (n.dispenseAnimationHandler != null) {
      n.dispenseAnimationHandler = null;
    }
  }

  Future<void> _syncStockFromProvider() async {
    final c = _controller;
    if (c == null || (!_cameraReady && !_aligning)) return;
    try {
      final list = await ref.read(placedProductsProvider.future);
      await _syncStock(list);
    } catch (e) {
      debugPrint('syncStockFromProvider: $e');
    }
  }

  Future<void> _syncStock(List<PlacedProduct> placed) async {
    final c = _controller;
    if (c == null || (!_cameraReady && !_aligning)) return;
    try {
      final map = stockBySlotFromPlaced(placed);
      debugPrint(
        'syncVendingStock: ${placed.length} Slots belegt, '
        'z.B. ${placed.take(5).map((p) => '${p.slotCode}=${p.stockQuantity}').join(', ')}',
      );
      await c.syncVendingStock(map);
    } catch (e) {
      debugPrint('syncVendingStock: $e');
    }
  }

  Future<void> _closeDeliveryFlap() async {
    final c = _controller;
    if (c == null || (!_cameraReady && !_aligning)) return;
    try {
      final ok = await c.setDeliveryFlapOpen(false);
      if (ok && mounted) setState(() => _flapOpen = false);
      _flapHover = false;
    } catch (e) {
      debugPrint('close flap: $e');
    }
  }

  Future<void> _applyCameraView(String viewId, {bool? forceLock}) async {
    final c = _controller;
    if (c == null) return;
    final preset = _cameraViews.firstWhere(
      (v) => v.id == viewId,
      orElse: () => _cameraViews.first,
    );
    final lock = forceLock ?? preset.lockByDefault;
    await c.setOrbitLock(false);
    await c.applyVendingCameraView(viewId);
    await c.setOrbitLock(lock);
    await c.updateZoomSensitivity(0.92);
    if (!mounted) return;
    setState(() {
      _orbitLocked = lock;
    });
  }

  Future<void> _toggleOrbitLock() async {
    final c = _controller;
    if (c == null || (!_cameraReady && !_aligning)) return;
    final next = !_orbitLocked;
    await c.setOrbitLock(next);
    if (mounted) setState(() => _orbitLocked = next);
  }

  Future<void> _reloadFrontView() async {
    await _applyCameraView('front', forceLock: true);
  }

  Future<void> _panByGlobalDelta(Offset delta) async {
    if (!_cameraReady || !_orbitLocked) return;
    final c = _controller;
    if (c == null) return;
    var dx = delta.dx;
    var dy = delta.dy;
    if (dx.abs() > _panTeleport || dy.abs() > _panTeleport) return;
    dx = dx.clamp(-_panMaxStep, _panMaxStep);
    dy = dy.clamp(-_panMaxStep, _panMaxStep);
    if (dx == 0 && dy == 0) return;
    await c.panByPixels(dx, dy);
  }

  void _onScenePanDown(PointerDownEvent e) {
    if (!_cameraReady) return;
    if ((e.buttons & kPrimaryButton) == 0) return;
    _scenePanLast = e.position;
    _scenePanPointer = e.pointer;
    _scenePanning = false;
  }

  void _onScenePanMove(PointerMoveEvent e) {
    if (_scenePanLast == null || e.pointer != _scenePanPointer) return;
    if (!_orbitLocked || !_cameraReady) return;
    if ((e.buttons & kPrimaryButton) == 0) return;
    final delta = e.position - _scenePanLast!;
    if (!_scenePanning) {
      if (delta.distance < _panStartSlop) return;
      setState(() => _scenePanning = true);
      _scenePanLast = e.position;
      return;
    }
    _scenePanLast = e.position;
    unawaited(_panByGlobalDelta(delta));
  }

  void _onScenePanEnd(PointerEvent e) {
    if (e.pointer != _scenePanPointer) return;
    final wasPanning = _scenePanning;
    final local = e.localPosition;
    _scenePanLast = null;
    _scenePanPointer = null;
    if (_scenePanning && mounted) {
      setState(() => _scenePanning = false);
    } else {
      _scenePanning = false;
    }
    // Klick (kein Ziehen): Produkt aus der Klappe entnehmen.
    if (!wasPanning) {
      unawaited(_tryCollectProductAt(local));
    }
  }

  Future<void> _tryCollectProductAt(Offset local) async {
    if (!_cameraReady || !_awaitingProductCollect) return;
    final c = _controller;
    if (c == null) return;
    try {
      final overZone = await c.isOverCollectZone(local.dx, local.dy);
      if (!overZone) return;

      final ok = await c.collectDispensedProduct();
      if (!ok) return;
      await c.setDeliveryFlapOpen(false);
      if (mounted) {
        setState(() {
          _awaitingProductCollect = false;
          _flapOpen = false;
          _flapHover = false;
        });
      }
    } catch (err) {
      debugPrint('collect product: $err');
    }
  }

  Future<void> _onFlapHoverMove(Offset local) async {
    if (!_cameraReady) return;
    final c = _controller;
    if (c == null) return;
    _flapHoverDebounce?.cancel();
    _flapHoverDebounce = Timer(const Duration(milliseconds: 30), () async {
      try {
        final over = await c.isOverDeliveryFlap(local.dx, local.dy);
        if (over == _flapHover) return;
        _flapHover = over;
        // Darüberfahren öffnet immer; nach Kauf zusätzlich offen halten bis Entnahme.
        final wantOpen = over || _awaitingProductCollect;
        final ok = await c.setDeliveryFlapOpen(wantOpen, angleDeg: 52);
        if (ok && mounted) {
          setState(() => _flapOpen = wantOpen);
        }
      } catch (err) {
        debugPrint('flap hover: $err');
      }
    });
  }

  Future<void> _onFlapHoverExit() async {
    _flapHoverDebounce?.cancel();
    if (!_flapHover && !_flapOpen) return;
    _flapHover = false;
    if (_awaitingProductCollect) return;
    final c = _controller;
    if (c == null) return;
    try {
      final ok = await c.setDeliveryFlapOpen(false);
      if (ok && mounted) {
        setState(() => _flapOpen = false);
      }
    } catch (err) {
      debugPrint('flap hover exit: $err');
    }
  }

  Future<void> _suspendViewer({required String statusText}) async {
    _clearDispenseHandler();
    final c = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
        _bootstrapped = false;
        _cameraReady = false;
        _aligning = false;
        _statusText = statusText;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    c?.removeListener(_onControllerChanged);
    try {
      c?.dispose();
    } catch (_) {}
    if (_slotAcquired) {
      ProductModelViewerLock.release();
      _slotAcquired = false;
    }
  }

  Future<void> _open2dUi() async {
    if (_opening2d || _openingAdmin || _openingPresentation || !mounted) {
      return;
    }
    _opening2d = true;
    // 3D-WebView bewusst behalten — Rückkehr zu 3D ohne Neu-Laden.
    if (!mounted) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const VendingMachineScreen(show3dToggle: true),
      ),
    );
    if (!mounted) return;
    _opening2d = false;
    if (result == 'admin') {
      unawaited(_openAdmin());
    }
  }

  Future<void> _openAdmin() async {
    if (_opening2d || _openingAdmin || _openingPresentation || !mounted) {
      return;
    }
    _openingAdmin = true;
    // Power3D erlaubt nur eine WebView — Sperre freigeben, damit Admin-Produkt-3D geht.
    await _suspendViewer(statusText: 'Admin…');
    if (!mounted) return;
    await openAdminArea(context);
    if (!mounted) return;
    _openingAdmin = false;
    unawaited(_bootstrap());
  }

  Future<void> _openPresentation() async {
    if (_opening2d || _openingAdmin || _openingPresentation || !mounted) {
      return;
    }
    _openingPresentation = true;
    await _suspendViewer(statusText: 'Präsentation…');
    if (!mounted) return;
    await openPresentationArea(context);
    if (!mounted) return;
    _openingPresentation = false;
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _flapHoverDebounce?.cancel();
    _clearDispenseHandler();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    if (_slotAcquired) ProductModelViewerLock.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(placedProductsProvider, (prev, next) {
      next.whenData((list) => unawaited(_syncStock(list)));
    });

    ref.listen(
      vendingSessionProvider.select((s) => s.phase),
      (prev, next) {
        if (next == VendingMachinePhase.ready &&
            prev != VendingMachinePhase.ready &&
            !_awaitingProductCollect) {
          unawaited(_closeDeliveryFlap());
        }
      },
    );

    ref.listen(vendingSessionProvider, (prev, next) {
      if (!_cameraReady || _controller == null) return;
      unawaited(_syncHudOled(next));
    });

    final session = ref.watch(vendingSessionProvider);

    final darkBg = _materialStyleId == 'blender_dark' ||
        _materialStyleId == 'enamel';
    return Scaffold(
      // Blender-ähnlicher Studio-Hintergrund
      backgroundColor:
          darkBg ? const Color(0xFF2E3238) : const Color(0xFF7A8088),
      appBar: AppBar(
        backgroundColor:
            darkBg ? const Color(0xFF1E2228) : const Color(0xFF5A6068),
        foregroundColor: Colors.white,
        title: const Text('Snackautomat · Format .glb'),
        actions: [
          IconButton(
            tooltip: _orbitLocked
                ? 'Drehen gesperrt · Linksklick = verschieben · Rad = Zoom'
                : 'Ansicht entsperrt (Drehen erlaubt)',
            icon: Icon(_orbitLocked ? Icons.lock : Icons.lock_open),
            color: _orbitLocked ? Colors.lightGreenAccent : Colors.orangeAccent,
            onPressed: !_cameraReady || _controller == null
                ? null
                : () => unawaited(_toggleOrbitLock()),
          ),
          IconButton(
            tooltip: 'Präsentation',
            icon: const Icon(Icons.slideshow_rounded),
            onPressed: (_opening2d || _openingAdmin || _openingPresentation)
                ? null
                : () => unawaited(_openPresentation()),
          ),
          IconButton(
            tooltip: 'Admin',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: (_opening2d || _openingAdmin || _openingPresentation)
                ? null
                : () => unawaited(_openAdmin()),
          ),
        ],
      ),
      body: _buildBody(session),
    );
  }

  Widget _buildBody(VendingSessionState session) {
    if (_blocked) {
      return const Center(
        child: Text('3D-Viewer belegt — Admin-Vorschau schließen.'),
      );
    }
    if (_error != null) {
      return Center(child: Text('3D-Fehler: $_error'));
    }
    if (!_bootstrapped || _controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.cyanAccent),
            if (_statusText != null) ...[
              const SizedBox(height: 16),
              Text(
                _statusText!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MouseRegion(
          onHover: (e) => unawaited(_onFlapHoverMove(e.localPosition)),
          onExit: (_) => unawaited(_onFlapHoverExit()),
          child: Listener(
            onPointerDown: _onScenePanDown,
            onPointerMove: (e) {
              _onScenePanMove(e);
              unawaited(_onFlapHoverMove(e.localPosition));
            },
            onPointerUp: _onScenePanEnd,
            onPointerCancel: _onScenePanEnd,
            child: Power3D.fromAsset(
              VendingMachine3DLandingScreen.modelAsset,
              controller: _controller,
              onModelLoaded: () => unawaited(_onModelLoaded()),
              zoomSensitivity: 0.55,
              exposure: 1.2,
              contrast: 1.05,
              lights: const [
                LightingConfig(
                  type: LightType.hemispheric,
                  intensity: 1.1,
                  color: Color(0xFFF5F7FA),
                ),
                LightingConfig(
                  type: LightType.directional,
                  intensity: 1.0,
                  color: Color(0xFFFFF5E6),
                ),
              ],
              loadingUi: (context, controller) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.cyanAccent),
                    const SizedBox(height: 16),
                    Text(
                      _statusText ?? 'Automaten-Modell laden…',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              errorWidget: const Center(
                child: Text(
                  'Automaten-Modell konnte nicht geladen werden.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
        // Bis Frontansicht sitzt: WebView komplett abdecken (kein Hinter-/Zoom-Flash).
        if (!_cameraReady)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF1A1F26),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.cyanAccent),
                    const SizedBox(height: 16),
                    Text(
                      _statusText ?? 'Automaten-Modell laden…',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.15, -0.05),
                radius: 1.15,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
        // Oben links: 2D (gleiche Position wie 3D-Switch auf 2D-Seite) · Front · Ausgabe
        Positioned(
          top: 10,
          left: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SceneCornerAction(
                icon: Icons.grid_view_rounded,
                label: '2D',
                tooltip: 'Zur 2D-Ansicht',
                enabled: !_opening2d && !_openingAdmin && !_openingPresentation,
                onTap: () => unawaited(_open2dUi()),
              ),
              const SizedBox(width: 10),
              _SceneCornerAction(
                icon: Icons.restart_alt,
                label: 'Frontansicht',
                tooltip: 'Frontansicht neu laden',
                enabled: _cameraReady && _controller != null,
                onTap: () => unawaited(_reloadFrontView()),
              ),
              const SizedBox(width: 10),
              _DeliveryWatchEye(
                active: _awaitingProductCollect && _cameraReady,
                enabled: _cameraReady && _controller != null,
                onTap: () => unawaited(_applyCameraView('dispense')),
              ),
            ],
          ),
        ),
        // Bedienung nur in der Sidebar
        VendingControlSidebar(session: session),
      ],
    );
  }
}

/// Blinkendes Auge: aktiv wenn Ware in der Ausgabe liegt; Klick → Ausgabe-Kamera.
class _DeliveryWatchEye extends StatefulWidget {
  const _DeliveryWatchEye({
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_DeliveryWatchEye> createState() => _DeliveryWatchEyeState();
}

class _DeliveryWatchEyeState extends State<_DeliveryWatchEye>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _DeliveryWatchEye oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncPulse();
  }

  void _syncPulse() {
    if (widget.active) {
      if (!_pulse.isAnimating) {
        unawaited(_pulse.repeat(reverse: true));
      }
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = widget.active ? _pulse.value : 0.0;
        final glow = Color.lerp(
          const Color(0xFF4A5560),
          const Color(0xFF00F2FE),
          t,
        )!;
        final iconColor = Color.lerp(
          Colors.white54,
          const Color(0xFFE8FFFF),
          t,
        )!;
        return _SceneCornerAction(
          icon: Icons.visibility_rounded,
          label: 'Produktausgabe',
          tooltip: widget.active
              ? 'Produkt bereit · zur Ausgabe springen'
              : 'Produktausgabe',
          enabled: widget.enabled,
          onTap: widget.onTap,
          iconColor: iconColor,
          borderColor: glow.withValues(alpha: 0.45 + 0.45 * t),
          fillColor: Color.lerp(
            const Color(0xCC1A1E24),
            const Color(0xEE003A44),
            t,
          ),
          glow: widget.active
              ? BoxShadow(
                  color: glow.withValues(alpha: 0.35 + 0.45 * t),
                  blurRadius: 10 + 14 * t,
                  spreadRadius: 1 + 2 * t,
                )
              : null,
        );
      },
    );
  }
}

/// Runde Eck-Schaltfläche mit Beschriftung darunter (Vorderansicht neu laden / Produktausgabe).
class _SceneCornerAction extends StatelessWidget {
  const _SceneCornerAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    this.iconColor,
    this.borderColor,
    this.fillColor,
    this.glow,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? borderColor;
  final Color? fillColor;
  final BoxShadow? glow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fillColor ?? const Color(0xCC1A1E24),
                  border: Border.all(
                    color: borderColor ?? const Color(0xFF4A5560).withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  boxShadow: glow == null ? null : [glow!],
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? Colors.white54,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
