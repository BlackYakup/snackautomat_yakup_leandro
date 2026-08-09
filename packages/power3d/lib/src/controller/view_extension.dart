part of 'power3d_controller.dart';

/// Erweiterung fuer Kamera und Ansicht von [Power3DController].
extension ViewExtension on Power3DController {
  /// Setzt die Kamera auf Standardposition und -ausrichtung zurueck.
  Future<void> resetView() async {
    await _evalJs('resetView()');
  }

  /// Setzt die gesamte Szene auf den Anfangszustand zurueck.
  /// Stoppt Animationen, leert Auswahl, blendet Teile ein und setzt Kamera zurueck.
  Future<void> resetScene() async {
    await _evalJs('resetScene()');
  }

  /// Aktualisiert die Auto-Rotation der Kamera.
  ///
  /// [enabled]: Ob Auto-Rotation aktiv ist.
  /// [speed]: Rotationsgeschwindigkeits-Multiplikator (Standard 1.0).
  /// [direction]: Drehung im oder gegen den Uhrzeigersinn.
  /// [stopAfter]: Optionale Dauer, nach der die Rotation automatisch stoppt.
  Future<void> updateRotation({
    bool? enabled,
    double? speed,
    RotationDirection? direction,
    Duration? stopAfter,
  }) async {
    final newState = value.copyWith(
      autoRotate: enabled,
      rotationSpeed: speed,
      rotationDirection: direction,
      rotationStopAfter: stopAfter,
    );
    value = newState;

    final dirStr = newState.rotationDirection == RotationDirection.clockwise
        ? 'clockwise'
        : 'counterClockwise';
    final stopMs = newState.rotationStopAfter?.inMilliseconds;

    await _evalJs(
      'toggleAutoRotate(${newState.autoRotate}, ${newState.rotationSpeed}, "$dirStr", $stopMs)',
    );
  }

  @Deprecated('Use updateRotation instead')
  Future<void> toggleAutoRotate(bool enabled) async {
    await updateRotation(enabled: enabled);
  }

  /// Sperrt oder entsperrt die Objektposition (Panning).
  /// Bei [locked] drehen/zoomen moeglich, Verschieben nicht.
  Future<void> setLockPosition(bool locked) async {
    value = value.copyWith(isPositionLocked: locked);
    await _evalJs('setLockPosition($locked)');
  }

  /// Sperrt die Orbit-Rotation und behält Zoom sowie sanftes Linksziehen-Pan.
  ///
  /// Bei [locked] sind Alpha/Beta fixiert. Linksziehen verschiebt mit begrenzten Schritten
  /// (keine plötzlichen Teleports). Mausrad zoomt zur Cursorposition.
  Future<void> setOrbitLock(bool locked) async {
    value = value.copyWith(isPositionLocked: locked);
    await ensureProjectionHelpers();
    await _evalJs('''
(function(locked){
  if (!window.scene || !window.scene.activeCamera) return;
  var camera = window.scene.activeCamera;
  function clearInertia() {
    camera.inertialAlphaOffset = 0;
    camera.inertialBetaOffset = 0;
    camera.inertialRadiusOffset = 0;
    camera.inertialPanningX = 0;
    camera.inertialPanningY = 0;
  }
  if (locked) {
    camera.lowerAlphaLimit = camera.alpha;
    camera.upperAlphaLimit = camera.alpha;
    camera.lowerBetaLimit = camera.beta;
    camera.upperBetaLimit = camera.beta;
    // Built-in-Pan/Orbit aus — eigener Smooth-Pan (kein Wegspringen).
    camera.panningSensibility = 0;
    camera.panningInertia = 0;
    camera.inertia = 0;
    try { camera.panningMouseButton = -1; } catch (e) {}
    try {
      // Linksklick darf nicht mehr orbitieren (nur unser Pan).
      var ptr = camera.inputs && camera.inputs.attached && camera.inputs.attached.pointers;
      if (ptr) {
        ptr.buttons = [1, 2];
        ptr.angularSensibilityX = 999999;
        ptr.angularSensibilityY = 999999;
      }
    } catch (e) {}
    clearInertia();
    if (typeof setupSmoothLeftPan === 'function') setupSmoothLeftPan(true);
  } else {
    if (typeof setupSmoothLeftPan === 'function') setupSmoothLeftPan(false);
    camera.lowerAlphaLimit = null;
    camera.upperAlphaLimit = null;
    camera.lowerBetaLimit = 0.72;
    camera.upperBetaLimit = Math.PI - 0.72;
    camera.panningSensibility = 1000;
    camera.panningInertia = 0.9;
    camera.inertia = 0.9;
    try { camera.panningMouseButton = 2; } catch (e) {}
    try {
      var ptr2 = camera.inputs && camera.inputs.attached && camera.inputs.attached.pointers;
      if (ptr2) {
        ptr2.buttons = [0, 1, 2];
        ptr2.angularSensibilityX = 1000;
        ptr2.angularSensibilityY = 1000;
      }
    } catch (e) {}
    clearInertia();
  }
})($locked)
''');
  }

  /// Verschiebt die Kamera um [dx]/[dy] CSS-Pixel (Canvas-Feeling, gecappt in JS).
  Future<void> panByPixels(double dx, double dy) async {
    if (!_alive) return;
    await ensureProjectionHelpers();
    await _evalJs('panByPixels($dx, $dy)');
  }

  /// Aktualisiert Zoom-Grenzen und -Verhalten der Kamera.
  ///
  /// [enabled]: Ob Zoom-Interaktion erlaubt ist.
  /// [min]: Minimal erlaubte Zoom-Distanz.
  /// [max]: Maximal erlaubte Zoom-Distanz.
  /// [sensitivity]: Zoom-Empfindlichkeit (0.0 = schnellste, 1.0 = langsamste).
  Future<void> updateZoom({
    bool? enabled,
    double? min,
    double? max,
    double? sensitivity,
  }) async {
    value = value.copyWith(
      enableZoom: enabled,
      minZoom: min,
      maxZoom: max,
      zoomSensitivity: sensitivity,
    );
    await _evalJs(
      'updateZoom(${value.enableZoom}, ${value.minZoom}, ${value.maxZoom})',
    );
    if (sensitivity != null) {
      await updateZoomSensitivity(sensitivity);
    }
  }

  /// Steuert die Empfindlichkeit von Pinch-Zoom und Mausrad.
  ///
  /// [sensitivity]: Wert von 0.0 (schnellste) bis 1.0 (langsamste). Standard 0.5.
  Future<void> updateZoomSensitivity(double sensitivity) async {
    final clamped = sensitivity.clamp(0.0, 1.0);
    value = value.copyWith(zoomSensitivity: clamped);
    // Bevorzuge % des Radius pro Mausrad-Stufe (sanft bei Ortho/kleinem Radius).
    // Empfindlichkeit 1.0 → 0,6 % pro Stufe, 0.0 → 5 % pro Stufe.
    final pct = (0.05 - clamped * 0.044).clamp(0.005, 0.05);
    await _evalJs('''
(function(s, pct){
  if (!window.scene || !window.scene.activeCamera) return;
  var camera = window.scene.activeCamera;
  camera.wheelDeltaPercentage = pct;
  camera.wheelPrecision = 5 + (2000 - 5) * s;
  camera.pinchPrecision = camera.wheelPrecision * 4;
})($clamped, $pct)
''');
  }

  /// Erstellt einen Screenshot der aktuellen 3D-Ansicht und speichert ihn unter [savePath].
  /// Hinweis: [savePath] muss Dateiname und Endung enthalten (z. B. 'path/to/shot.png').
  Future<void> takeScreenshot(String savePath) async {
    _pendingScreenshotPath = savePath;
    await _evalJs('takeScreenshot()');
  }

  /// Setzt Kameraposition und -ausrichtung.
  Future<void> setCameraPosition({
    double? alpha,
    double? beta,
    double? radius,
  }) async {
    final newState = value.copyWith(
      cameraAlpha: alpha,
      cameraBeta: beta,
      cameraRadius: radius,
    );
    value = newState;
    await _evalJs(
      'setCameraPosition(${newState.cameraAlpha}, ${newState.cameraBeta}, ${newState.cameraRadius})',
    );
  }

  /// Richtet eine Blender-ähnliche Frontansicht ein (Glas zur Kamera, ganzer Automat sichtbar).
  Future<void> frameFrontView({
    double? alpha,
    double? beta,
    double? radiusMul,
    bool orthographic = true,
  }) async {
    await applyVendingCameraView(
      'front',
      alpha: alpha,
      beta: beta,
      radiusMul: radiusMul,
      orthographic: orthographic,
    );
  }

  /// Benannte Kameravoreinstellungen fuer den Snackautomaten (Front / 3D / Buy / Product / Dispense).
  ///
  /// [viewId]: `front` | `front3d` | `buy` | `product` | `dispense`
  Future<void> applyVendingCameraView(
    String viewId, {
    double? alpha,
    double? beta,
    double? radiusMul,
    bool? orthographic,
  }) async {
    final id = viewId.replaceAll("'", '');
    final a = alpha;
    final b = beta;
    final m = radiusMul;
    final orthoJs = orthographic == null ? 'null' : '$orthographic';
    final aJs = a == null ? 'null' : '$a';
    final bJs = b == null ? 'null' : '$b';
    final mJs = m == null ? 'null' : '$m';
    await _evalJs('''
(function(opts){
  if (!window.scene || !window.scene.activeCamera) return null;
  var camera = window.scene.activeCamera;
  function keep(mesh){
    if (!mesh || !mesh.getTotalVertices || mesh.getTotalVertices() < 3 || !mesh.isEnabled()) return false;
    var n = (mesh.name || '').toLowerCase();
    if (n.indexOf('__root__') >= 0) return false;
    if (n.indexOf('wirecol') >= 0) return false;
    if (n.indexOf('physics') >= 0) return false;
    var ok =
      n.indexOf('vending_') >= 0 ||
      n.indexOf('motor_') >= 0 ||
      n.indexOf('divider_') >= 0 ||
      n.indexOf('elevator_') >= 0 ||
      n.indexOf('right_display') >= 0 ||
      n.indexOf('glass') >= 0 ||
      n.indexOf('product_') >= 0 ||
      n.indexOf('labelstrip') >= 0 ||
      n.indexOf('labelplate') >= 0 ||
      n.indexOf('labeltext') >= 0 ||
      n.indexOf('ui_') >= 0 ||
      n.indexOf('coinmod_') >= 0 ||
      n.indexOf('coinreturn_') >= 0 ||
      n.indexOf('kp_') >= 0 ||
      n.indexOf('eport_') >= 0;
    return ok;
  }
  function isShell(mesh){
    var n = (mesh.name || '').toLowerCase();
    return n.indexOf('vending_leftbody') >= 0 ||
      n.indexOf('vending_rightpanel') >= 0 ||
      n.indexOf('vending_glass') >= 0 ||
      n.indexOf('vending_roof') >= 0 ||
      n.indexOf('vending_foot') >= 0 ||
      n.indexOf('glasspane') >= 0;
  }
  function accumulate(meshes, outMin, outMax){
    var used = 0;
    meshes.forEach(function(mesh){
      try {
        var bi = mesh.getBoundingInfo();
        if (!bi) return;
        var bmin = bi.boundingBox.minimumWorld;
        var bmax = bi.boundingBox.maximumWorld;
        outMin.copyFrom(BABYLON.Vector3.Minimize(outMin, bmin));
        outMax.copyFrom(BABYLON.Vector3.Maximize(outMax, bmax));
        used++;
      } catch (e) {}
    });
    return used;
  }
  var meshes = window.scene.meshes.filter(keep);
  if (!meshes.length) {
    meshes = window.scene.meshes.filter(function(mesh){
      return mesh && mesh.getTotalVertices && mesh.getTotalVertices() > 0 && mesh.isEnabled();
    });
  }
  // Nur Gehaeuse-Framing bei Ausreissern / doppelten Automaten bevorzugen.
  var shellMeshes = meshes.filter(isShell);
  // LeftBody allein bevorzugen, falls vorhanden — stabilstes Frame-Ziel.
  var leftBody = meshes.filter(function(mesh){
    var n = (mesh.name || '').toLowerCase();
    return n.indexOf('leftbody') >= 0 || n.indexOf('vending_leftbody') >= 0;
  });
  var min = new BABYLON.Vector3(1e9,1e9,1e9);
  var max = new BABYLON.Vector3(-1e9,-1e9,-1e9);
  var used = accumulate(leftBody.length ? leftBody : (shellMeshes.length ? shellMeshes : meshes), min, max);
  if (!used) {
    min = new BABYLON.Vector3(1e9,1e9,1e9);
    max = new BABYLON.Vector3(-1e9,-1e9,-1e9);
    used = accumulate(shellMeshes.length ? shellMeshes : meshes, min, max);
  }
  if (!used) {
    min = new BABYLON.Vector3(1e9,1e9,1e9);
    max = new BABYLON.Vector3(-1e9,-1e9,-1e9);
    used = accumulate(meshes, min, max);
  }
  if (!used) return null;
  var center = min.add(max).scale(0.5);
  var size = max.subtract(min);
  // Wenn BBox noch wie zwei Automaten wirkt, dichtere Haelfte behalten.
  if (size.x > 8 || size.y > 8 || size.z > 8) {
    var midX = center.x;
    var left = [], right = [];
    var pool = leftBody.length ? leftBody : (shellMeshes.length ? shellMeshes : meshes);
    pool.forEach(function(mesh){
      try {
        var c = mesh.getBoundingInfo().boundingBox.centerWorld;
        (c.x < midX ? left : right).push(mesh);
      } catch (e) {}
    });
    var cluster = right.length >= left.length ? right : left;
    if (cluster.length) {
      min = new BABYLON.Vector3(1e9,1e9,1e9);
      max = new BABYLON.Vector3(-1e9,-1e9,-1e9);
      used = accumulate(cluster, min, max);
      center = min.add(max).scale(0.5);
      size = max.subtract(min);
    }
  }
  // Absoluter Fallback: bei absurder Groesse Einheitsbox am Ursprung.
  if (Math.max(size.x, size.y, size.z) > 12) {
    center = new BABYLON.Vector3(0, 0.6, 0);
    size = new BABYLON.Vector3(1.7, 2.0, 1.2);
    used = -1;
  }
  var engine = window.scene.getEngine();
  var aspect = engine.getAspectRatio(camera);
  var view = opts.viewId || 'front';
  var presets = {
    // +2 Rad-Ticks raus (×1.035²) gegenüber 1.02 → Automat nicht zu nah am Rand
    front: {
      alpha: Math.PI / 2, beta: Math.PI / 2, radiusMul: 1.093, ortho: true,
      tx: 0, ty: 0, tz: 0
    },
    front3d: {
      alpha: Math.PI / 2 + 0.42, beta: 1.22, radiusMul: 1.55, ortho: false,
      tx: 0, ty: 0, tz: 0
    },
    buy: {
      alpha: Math.PI / 2 - 0.12, beta: Math.PI / 2, radiusMul: 0.36, ortho: true,
      tx: size.x * 0.38, ty: size.y * 0.02, tz: size.z * 0.28
    },
    product: {
      alpha: Math.PI / 2, beta: Math.PI / 2, radiusMul: 0.48, ortho: true,
      tx: -size.x * 0.08, ty: size.y * 0.04, tz: size.z * 0.05
    },
    dispense: {
      alpha: Math.PI / 2, beta: Math.PI / 2 - 0.18, radiusMul: 0.32, ortho: true,
      tx: 0, ty: -size.y * 0.42, tz: size.z * 0.22
    }
  };
  var p = presets[view] || presets.front;
  var pad = opts.radiusMul != null ? opts.radiusMul : p.radiusMul;
  var alpha = opts.alpha != null ? opts.alpha : p.alpha;
  var beta = opts.beta != null ? opts.beta : p.beta;
  var useOrtho = opts.orthographic != null ? opts.orthographic : p.ortho;
  var target = center.add(new BABYLON.Vector3(p.tx, p.ty, p.tz));
  // Orbit-Limits zuerst leeren — sonst behält eine gesperrte Ansicht schiefe Alpha/Beta
  // und setTarget/alpha-Zuweisungen werden ignoriert (Babylon begrenzt).
  camera.lowerAlphaLimit = null;
  camera.upperAlphaLimit = null;
  camera.lowerBetaLimit = null;
  camera.upperBetaLimit = null;
  camera.setTarget(target);
  camera.alpha = alpha;
  camera.beta = beta;
  camera.panningSensibility = 0;
  // Near-Plane-Clipping des Gehaeuses in der Naehe vermeiden.
  camera.minZ = 0.01;
  camera.maxZ = Math.max(200, Math.max(size.x, size.y, size.z) * 20 + 50);
  // Sanftes Mausrad: kleine %-Schritte (Perspektive; Ortho nutzt Frustum-Zoom).
  camera.wheelDeltaPercentage = 0.01;
  camera.wheelPrecision = 1200;
  camera.pinchPrecision = 4800;
  // Kamera ausserhalb des Gehaeuses halten (Radius zur Front + Rand).
  // Staerkere Freistellung, damit Orbit/Zoom nicht in den Schrank geht.
  var shellClearance = Math.max(size.z, size.x * 0.4, size.y * 0.35) * 0.75 + 1.15;
  window._vendingCamGuard = {
    cx: center.x, cy: center.y, cz: center.z,
    minRadius: shellClearance,
    maxTargetOff: Math.max(size.x, size.y, size.z) * 0.18,
    // Extreme Unter-/Ueberwinkel vermeiden, die offene Gehaeuserueckseiten zeigen.
    minBeta: 0.72,
    maxBeta: Math.PI - 0.72
  };
  if (useOrtho) {
    var halfH = Math.max(size.y * 0.5, (size.x * 0.5) / Math.max(aspect, 0.01)) * pad;
    camera.mode = BABYLON.Camera.ORTHOGRAPHIC_CAMERA;
    // Kamera bleibt DRAUSSEN; Zoom aendert nur das Ortho-Frustum (kein Durchlaufen).
    window._power3dOrthoCamDist = shellClearance;
    window._power3dOrthoHalf = halfH;
    window._power3dOrthoHalfMin = Math.max(halfH * 0.12, 0.08);
    window._power3dOrthoHalfMax = halfH * 2.8;
    camera.radius = shellClearance;
    camera.lowerRadiusLimit = shellClearance;
    camera.upperRadiusLimit = shellClearance;
    function applyOrthoHalf(h) {
      var a2 = window.scene.getEngine().getAspectRatio(camera);
      camera.orthoTop = h;
      camera.orthoBottom = -h;
      camera.orthoLeft = -h * a2;
      camera.orthoRight = h * a2;
    }
    applyOrthoHalf(halfH);
    if (!window._power3dOrthoZoomBound) {
      window._power3dOrthoZoomBound = true;
      // Mausrad-Radius-Versuche in Frustum-Zoom umwandeln; Kameradistanz fixieren.
      camera.onAfterCheckInputsObservable.add(function(){
        if (camera.mode !== BABYLON.Camera.ORTHOGRAPHIC_CAMERA) return;
        var dist = window._power3dOrthoCamDist;
        if (dist == null) return;
        if (Math.abs(camera.radius - dist) > 1e-4) {
          // Mausrad wollte Radius ändern → als Frustum-Zoom behandeln.
          var ratio = camera.radius / dist;
          var next = (window._power3dOrthoHalf || halfH) * ratio;
          var lo = window._power3dOrthoHalfMin || 0.08;
          var hi = window._power3dOrthoHalfMax || halfH * 3;
          window._power3dOrthoHalf = Math.min(hi, Math.max(lo, next));
          camera.radius = dist;
        }
        camera.lowerRadiusLimit = dist;
        camera.upperRadiusLimit = dist;
        applyOrthoHalf(window._power3dOrthoHalf);
      });
      // Extra: direktes Mausrad auf dem Canvas für zuverlässigen Ortho-Zoom (Radius gesperrt).
      var canvas = window.scene.getEngine().getRenderingCanvas();
      if (canvas && !window._power3dOrthoWheel) {
        window._power3dOrthoWheel = true;
        canvas.addEventListener('wheel', function(e){
          if (!window.scene || !window.scene.activeCamera) return;
          var cam = window.scene.activeCamera;
          if (cam.mode !== BABYLON.Camera.ORTHOGRAPHIC_CAMERA) return;
          e.preventDefault();
          var factor = e.deltaY > 0 ? 1.035 : 0.965;
          var next = (window._power3dOrthoHalf || 1) * factor;
          var lo = window._power3dOrthoHalfMin || 0.08;
          var hi = window._power3dOrthoHalfMax || 4;
          window._power3dOrthoHalf = Math.min(hi, Math.max(lo, next));
          cam.radius = window._power3dOrthoCamDist;
          var a2 = window.scene.getEngine().getAspectRatio(cam);
          var h = window._power3dOrthoHalf;
          cam.orthoTop = h; cam.orthoBottom = -h;
          cam.orthoLeft = -h * a2; cam.orthoRight = h * a2;
        }, { passive: false });
      }
    }
  } else {
    camera.mode = BABYLON.Camera.PERSPECTIVE_CAMERA;
    camera.fov = 0.5;
    var extent = Math.max(size.x, size.y * 1.05, size.z * 0.55);
    var radius = Math.max(extent * pad, shellClearance * 1.35);
    camera.radius = radius;
    // Nie näher als Shell-Clearance — blockiert Durchlaufen / Innenansichten.
    camera.lowerRadiusLimit = shellClearance;
    camera.upperRadiusLimit = Math.max(radius * 2.8, shellClearance * 3.5);
    camera.lowerBetaLimit = window._vendingCamGuard.minBeta;
    camera.upperBetaLimit = window._vendingCamGuard.maxBeta;
  }
  if (typeof window.ensureVendingCameraGuard === 'function') {
    window.ensureVendingCameraGuard();
  }
  console.log('[JS] applyVendingCameraView', JSON.stringify({
    view: view, alpha: camera.alpha, beta: camera.beta, radius: camera.radius,
    orthographic: !!useOrtho, used: used, shellClearance: shellClearance,
    orthoHalf: window._power3dOrthoHalf || null,
    target: {x: target.x, y: target.y, z: target.z},
    size: {x: size.x, y: size.y, z: size.z}
  }));
  return true;
})({viewId: '$id', alpha: $aJs, beta: $bJs, radiusMul: $mJs, orthographic: $orthoJs})
''');
  }

  Future<void> _saveScreenshotToFile(String base64Data, String path) async {
    try {
      final String data = base64Data.contains(',')
          ? base64Data.split(',')[1]
          : base64Data;
      final bytes = base64Decode(data);
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      debugPrint('Screenshot saved to: $path');
    } catch (e) {
      debugPrint('Failed to save screenshot: $e');
    }
  }
}
