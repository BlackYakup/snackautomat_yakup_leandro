part of 'power3d_controller.dart';

/// World↔Screen Projektion / Picking für Flutter-Hotspot-Anker.
extension ProjectionExtension on Power3DController {
  /// Injiziert JS-Helfer und hängt Camera→Flutter Telemetry an.
  Future<void> ensureProjectionHelpers({bool force = false}) async {
    if (_projectionHelpersInjected && !force) return;
    await _evalJs(_projectionHelpersJs);
    _projectionHelpersInjected = true;
  }

  /// Liest aktuelle Kamera (für Polling, falls Messages ausbleiben).
  Future<
      ({
        double alpha,
        double beta,
        double radius,
        double? orthoHalf,
        double tx,
        double ty,
        double tz,
      })?> readCameraPose() async {
    if (!_alive) return null;
    await ensureProjectionHelpers();
    final raw = await _evalJs('readCameraPose()');
    final map = _parseJsJsonMap(raw);
    if (map == null) return null;
    return (
      alpha: (map['alpha'] as num?)?.toDouble() ?? 0,
      beta: (map['beta'] as num?)?.toDouble() ?? 0,
      radius: (map['radius'] as num?)?.toDouble() ?? 0,
      orthoHalf: (map['orthoHalf'] as num?)?.toDouble(),
      tx: (map['tx'] as num?)?.toDouble() ?? 0,
      ty: (map['ty'] as num?)?.toDouble() ?? 0,
      tz: (map['tz'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Projiziert alle Hotspot-Quads → Screen-Fraktionen + Sichtbarkeit (Front-Facing).
  Future<Map<String, ProjectedHotspot>> projectHotspotQuads(
    Map<String, WorldQuad> quads,
  ) async {
    if (!_alive || quads.isEmpty) return const {};
    await ensureProjectionHelpers();
    final payload = <String, dynamic>{
      for (final e in quads.entries) e.key: e.value.toJson(),
    };
    final raw = await _evalJs('projectHotspotQuads(${jsonEncode(payload)})');
    final map = _parseJsJsonMap(raw);
    if (map == null) return const {};
    final out = <String, ProjectedHotspot>{};
    for (final e in map.entries) {
      final v = e.value;
      if (v is! Map) continue;
      final m = Map<String, dynamic>.from(v);
      out[e.key] = ProjectedHotspot(
        left: (m['left'] as num?)?.toDouble() ?? 0,
        top: (m['top'] as num?)?.toDouble() ?? 0,
        width: (m['width'] as num?)?.toDouble() ?? 0.1,
        height: (m['height'] as num?)?.toDouble() ?? 0.1,
        visible: m['visible'] == true,
      );
    }
    return out;
  }

  /// Projiziert Weltpunkte → Canvas-Pixel (clientWidth/Height).
  Future<List<ProjectedScreenPoint>> projectWorldPoints(
    List<WorldPoint> points,
  ) async {
    if (!_alive || points.isEmpty) return const [];
    await ensureProjectionHelpers();

    final payload = jsonEncode([
      for (final p in points) {'x': p.x, 'y': p.y, 'z': p.z},
    ]);
    final raw = await _evalJs('projectWorldPoints($payload)');
    final list = _parseJsJsonList(raw);
    return [
      for (final e in list)
        if (e is Map)
          ProjectedScreenPoint(
            x: (e['x'] as num?)?.toDouble() ?? 0,
            y: (e['y'] as num?)?.toDouble() ?? 0,
            z: (e['z'] as num?)?.toDouble() ?? 0,
            visible: e['visible'] == true,
            canvasWidth: (e['canvasWidth'] as num?)?.toDouble() ?? 1,
            canvasHeight: (e['canvasHeight'] as num?)?.toDouble() ?? 1,
          ),
    ];
  }

  /// Raycast an Canvas-Koordinaten (CSS-Pixel relativ zum Canvas).
  Future<PickHit?> pickAtScreen(double x, double y) async {
    if (!_alive) return null;
    await ensureProjectionHelpers();
    final raw = await _evalJs('pickAtScreen($x, $y)');
    final map = _parseJsJsonMap(raw);
    if (map == null || map['hit'] != true) return null;
    final point = map['point'];
    if (point is! Map) return null;
    return PickHit(
      x: (point['x'] as num).toDouble(),
      y: (point['y'] as num).toDouble(),
      z: (point['z'] as num).toDouble(),
      meshName: map['meshName']?.toString(),
    );
  }

  /// true, wenn Cursor über PUSH-Klappe / Ausgabe liegt (Glas blockiert nicht).
  Future<bool> isOverDeliveryFlap(double x, double y) async {
    if (!_alive) return false;
    await ensureProjectionHelpers();
    final raw = await _evalJs('isOverDeliveryFlap($x, $y)');
    final map = _parseJsJsonMap(raw);
    return map?['over'] == true;
  }

  /// true, wenn Klick die Entnahmezone trifft (Klappe, Bay, Korb oder Produkt).
  /// Offene Klappe blockiert das Produkt dahinter nicht.
  Future<bool> isOverCollectZone(double x, double y) async {
    if (!_alive) return false;
    await ensureProjectionHelpers();
    final raw = await _evalJs('isOverCollectZone($x, $y)');
    final map = _parseJsJsonMap(raw);
    return map?['over'] == true;
  }

  /// Öffnet/schließt die Entnahmeklappe (`Vending_DeliveryFlap_Door`).
  /// Scharnier oben, Boden schwingt nach innen — Klappe bleibt sichtbar.
  Future<bool> setDeliveryFlapOpen(bool open, {double angleDeg = 42}) async {
    if (!_alive) return false;
    await ensureProjectionHelpers();
    final raw = await _evalJs(
      'setDeliveryFlapOpen(${open ? 'true' : 'false'}, $angleDeg)',
    );
    final map = _parseJsJsonMap(raw);
    return map?['ok'] == true;
  }

  /// Sichtbarkeit der Produkt-Meshes an DB-Bestand anpassen.
  ///
  /// [stockBySlot]: z.B. `{'A1': 3, 'C4': 0}` — die vordersten N unsold Stacks
  /// (s00 = Glas-Seite) sind sichtbar und rücken nach.
  Future<void> syncVendingStock(Map<String, int> stockBySlot) async {
    if (!_alive) return;
    await ensureProjectionHelpers();
    await _evalJs('syncVendingStock(${jsonEncode(stockBySlot)})');
  }

  /// Ausgabe-Sequenz: Aufzug → Spirale → **vorderstes** Produkt fällt → Aufzug park.
  ///
  /// [visibleStock] = aktueller Bestand vor dem Decrement.
  Future<bool> dispenseItem(
    String slotCode, {
    int visibleStock = 1,
    int durationMs = 5600,
  }) async {
    if (!_alive) return false;
    await ensureProjectionHelpers(force: true);
    final raw = await _evalJs(
      'dispenseVendingItem(${jsonEncode(slotCode)}, $visibleStock, $durationMs)',
    );
    final map = _parseJsJsonMap(raw);
    if (map?['ok'] != true) {
      return false;
    }
    final expected = (map?['durationMs'] as num?)?.toInt() ?? durationMs;
    final deadline = DateTime.now().add(
      Duration(milliseconds: expected + 2000),
    );
    while (DateTime.now().isBefore(deadline)) {
      if (!_alive) return false;
      final statusRaw = await _evalJs('isDispenseComplete()');
      final status = _parseJsJsonMap(statusRaw);
      if (status?['done'] == true) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await setDeliveryFlapOpen(true);
    return true;
  }

  /// Setzt den Aufzug auf die geparkte Ruhepose (unten).
  Future<bool> resetElevatorHome() async {
    if (!_alive) return false;
    await ensureProjectionHelpers(force: true);
    final raw = await _evalJs('resetElevatorHome()');
    final map = _parseJsJsonMap(raw);
    return map?['ok'] == true;
  }

  /// Entnimmt das ausgegebene Produkt (Klick in der Klappe/Bay).
  Future<bool> collectDispensedProduct() async {
    if (!_alive) return false;
    await ensureProjectionHelpers();
    final raw = await _evalJs('collectDispensedProduct()');
    final map = _parseJsJsonMap(raw);
    return map?['ok'] == true;
  }

  /// Studio-Beleuchtung + Environment, damit Metall/Glas in Flutter näher an Blender wirken.
  ///
  /// [stabilize] und [applyMaterials] können nach dem ersten Frame nachgezogen werden,
  /// damit die Kamera schneller sichtbar wird.
  Future<void> ensureVendingPresentation({
    bool stabilize = true,
    bool applyMaterials = true,
    bool forceHelpers = false,
  }) async {
    if (!_alive) return;
    await ensureProjectionHelpers(force: forceHelpers);
    await _evalJs('ensureVendingPresentation()');
    if (applyMaterials) {
      await _evalJs("applyVendingMaterialStyle('blender_dark')");
    }
    if (stabilize) {
      await _evalJs('stabilizeVendingShelf()');
    }
  }

  /// Produkte/Spiralen unter `__root__` + Bake-Pose (repariert Unparent-Drift).
  Future<void> stabilizeVendingShelf() async {
    if (!_alive) return;
    await ensureProjectionHelpers();
    await _evalJs('stabilizeVendingShelf()');
  }

  /// Spiegelt den SNACK-OLED-Inhalt auf `UI_HUD_Screen` (DynamicTexture).
  Future<bool> updateVendingHudOled(Map<String, dynamic> payload) async {
    if (!_alive) return false;
    await ensureProjectionHelpers();
    final raw = await _evalJs(
      'updateVendingHudOled(${jsonEncode(payload)})',
    );
    final map = _parseJsJsonMap(raw);
    return map?['ok'] == true;
  }

  /// Wechselt Shell-/Glas-Material-Look (`studio_metal` | `enamel` | `matte`).
  Future<void> applyVendingMaterialStyle(String styleId) async {
    if (!_alive) return;
    await ensureProjectionHelpers();
    final id = styleId.replaceAll("'", '');
    await _evalJs("applyVendingMaterialStyle('$id')");
  }

  /// Zoom zur Mausposition (Canvas-Pixel). [deltaY] wie bei Wheel (positiv = raus).
  Future<void> zoomAtScreen(double x, double y, double deltaY) async {
    if (!_alive) return;
    await ensureProjectionHelpers();
    await _evalJs('zoomAtScreen($x, $y, $deltaY)');
  }

  /// Bindet ein Screen-Rechteck (Fraktionen 0…1) an 4 Welt-Ecken auf dem Automaten.
  Future<WorldQuad?> bindScreenRectToWorld({
    required double left,
    required double top,
    required double width,
    required double height,
    required double viewerWidth,
    required double viewerHeight,
  }) async {
    if (!_alive) return null;
    await ensureProjectionHelpers();
    final raw = await _evalJs(
      'bindScreenRectToWorld($left,$top,$width,$height,$viewerWidth,$viewerHeight)',
    );
    final map = _parseJsJsonMap(raw);
    if (map == null || map['ok'] != true) return null;
    WorldPoint read(String key) {
      final m = map[key];
      if (m is! Map) return const WorldPoint(0, 0, 0);
      return WorldPoint(
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
        (m['z'] as num).toDouble(),
      );
    }

    return WorldQuad(
      topLeft: read('tl'),
      topRight: read('tr'),
      bottomRight: read('br'),
      bottomLeft: read('bl'),
    );
  }

  Map<String, dynamic>? _parseJsJsonMap(dynamic raw) {
    final decoded = _parseJsJson(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  List<dynamic> _parseJsJsonList(dynamic raw) {
    final decoded = _parseJsJson(raw);
    if (decoded is List) return decoded;
    return const [];
  }

  dynamic _parseJsJson(dynamic raw) {
    if (raw == null) return null;
    var s = raw.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    try {
      var decoded = jsonDecode(s);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }
}

/// Ergebnis einer Hotspot-Projektion (Fraktionen 0…1 relativ zum Canvas).
class ProjectedHotspot {
  const ProjectedHotspot({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.visible,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final bool visible;
}

/// Weltpunkt in Babylon-Koordinaten.
class WorldPoint {
  const WorldPoint(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  Map<String, double> toJson() => {'x': x, 'y': y, 'z': z};

  factory WorldPoint.fromJson(Map<String, dynamic> json) => WorldPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
        (json['z'] as num).toDouble(),
      );
}

/// Vier Ecken eines Hotspot-Rechtecks in der Welt.
class WorldQuad {
  const WorldQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final WorldPoint topLeft;
  final WorldPoint topRight;
  final WorldPoint bottomRight;
  final WorldPoint bottomLeft;

  List<WorldPoint> get points => [topLeft, topRight, bottomRight, bottomLeft];

  Map<String, dynamic> toJson() => {
        'tl': topLeft.toJson(),
        'tr': topRight.toJson(),
        'br': bottomRight.toJson(),
        'bl': bottomLeft.toJson(),
      };

  factory WorldQuad.fromJson(Map<String, dynamic> json) {
    WorldPoint p(String k) {
      final m = json[k];
      if (m is Map<String, dynamic>) return WorldPoint.fromJson(m);
      if (m is Map) {
        return WorldPoint.fromJson(Map<String, dynamic>.from(m));
      }
      return const WorldPoint(0, 0, 0);
    }

    return WorldQuad(
      topLeft: p('tl'),
      topRight: p('tr'),
      bottomRight: p('br'),
      bottomLeft: p('bl'),
    );
  }
}

/// Projizierter Screen-Punkt (Canvas-Pixel).
class ProjectedScreenPoint {
  const ProjectedScreenPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.visible,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final double x;
  final double y;
  final double z;
  final bool visible;
  final double canvasWidth;
  final double canvasHeight;
}

/// Treffer eines Screen-Picks.
class PickHit {
  const PickHit({
    required this.x,
    required this.y,
    required this.z,
    this.meshName,
  });

  final double x;
  final double y;
  final double z;
  final String? meshName;
}

const String _projectionHelpersJs = r'''
(function(){
  function canvasSize() {
    var engine = window.scene && window.scene.getEngine && window.scene.getEngine();
    var canvas = engine && engine.getRenderingCanvas && engine.getRenderingCanvas();
    var rw = engine ? engine.getRenderWidth() : 1;
    var rh = engine ? engine.getRenderHeight() : 1;
    var cw = canvas && canvas.clientWidth ? canvas.clientWidth : rw;
    var ch = canvas && canvas.clientHeight ? canvas.clientHeight : rh;
    return { engine: engine, canvas: canvas, rw: rw, rh: rh, cw: cw, ch: ch };
  }

  function toRender(sx, sy, sz) {
    return { x: sx * (sz.rw / Math.max(sz.cw, 1)), y: sy * (sz.rh / Math.max(sz.ch, 1)) };
  }

  function machinePlane() {
    var meshes = (window.scene.meshes || []).filter(function(m){
      if (!m || !m.getTotalVertices || m.getTotalVertices() < 3 || !m.isEnabled()) return false;
      var n = (m.name || '').toLowerCase();
      return n.indexOf('vending_') >= 0 || n.indexOf('right_display') >= 0 || n.indexOf('glass') >= 0;
    });
    if (!meshes.length) {
      meshes = (window.scene.meshes || []).filter(function(m){
        return m && m.getTotalVertices && m.getTotalVertices() > 0 && m.isEnabled();
      });
    }
    var min = new BABYLON.Vector3(1e9,1e9,1e9);
    var max = new BABYLON.Vector3(-1e9,-1e9,-1e9);
    var used = 0;
    meshes.forEach(function(mesh){
      try {
        var bi = mesh.getBoundingInfo();
        if (!bi) return;
        min = BABYLON.Vector3.Minimize(min, bi.boundingBox.minimumWorld);
        max = BABYLON.Vector3.Maximize(max, bi.boundingBox.maximumWorld);
        used++;
      } catch (e) {}
    });
    if (!used) return null;
    var center = min.add(max).scale(0.5);
    // Automaten-Front zeigt typischerweise in +Z (Front-Ortho alpha=PI/2).
    var normal = new BABYLON.Vector3(0, 0, 1);
    return {
      center: center,
      normal: normal,
      plane: BABYLON.Plane.FromPositionAndNormal(center, normal),
      min: min,
      max: max
    };
  }

  function resolvePoint(sx, sy) {
    if (!window.scene || !window.scene.activeCamera) return null;
    var sz = canvasSize();
    var rp = toRender(sx, sy, sz);
    var skipFlap = !!window._dispensedProductMesh;
    var hit = window.scene.pick(rp.x, rp.y, function(m){
      if (!m || !m.isEnabled() || !m.isVisible) return false;
      var n = String(m.name || '');
      if (n.indexOf('hotspot_') === 0) return false;
      if (skipFlap) {
        var low = n.toLowerCase();
        // Nur die Tür/PUSH überspringen — Bay bleibt treffbar
        if (low.indexOf('deliveryflap') >= 0 ||
            (low.indexOf('push') >= 0 && low.indexOf('flap') >= 0) ||
            low.indexOf('flap_door') >= 0 ||
            low.indexOf('flap_push') >= 0) {
          return false;
        }
      }
      return m.isPickable !== false;
    });
    if (hit && hit.hit && hit.pickedPoint) {
      return { x: hit.pickedPoint.x, y: hit.pickedPoint.y, z: hit.pickedPoint.z, meshName: hit.pickedMesh && hit.pickedMesh.name };
    }
    var mp = machinePlane();
    if (!mp) return null;
    var ray = window.scene.createPickingRay(rp.x, rp.y, BABYLON.Matrix.Identity(), window.scene.activeCamera);
    var d = ray.intersectsPlane(mp.plane);
    if (d == null) return null;
    var p = ray.origin.add(ray.direction.scale(d));
    return { x: p.x, y: p.y, z: p.z, meshName: null };
  }

  function applyOrthoHalf(cam, h) {
    var a2 = window.scene.getEngine().getAspectRatio(cam);
    cam.orthoTop = h;
    cam.orthoBottom = -h;
    cam.orthoLeft = -h * a2;
    cam.orthoRight = h * a2;
  }

  function projectOne(world, transform, viewport, sz) {
    var screen = BABYLON.Vector3.Project(world, BABYLON.Matrix.Identity(), transform, viewport);
    return {
      x: screen.x * (sz.cw / Math.max(sz.rw, 1)),
      y: screen.y * (sz.ch / Math.max(sz.rh, 1)),
      z: screen.z,
      visible: screen.z >= 0 && screen.z <= 1
    };
  }

  window.readCameraPose = function() {
    if (!window.scene || !window.scene.activeCamera) return JSON.stringify(null);
    var cam = window.scene.activeCamera;
    var t = cam.getTarget();
    return JSON.stringify({
      alpha: cam.alpha,
      beta: cam.beta,
      radius: cam.radius,
      orthoHalf: (typeof window._power3dOrthoHalf === 'number') ? window._power3dOrthoHalf : null,
      tx: t.x, ty: t.y, tz: t.z
    });
  };

  /** Quads { id: {tl,tr,br,bl} } → Screen-Fraktionen + visible (Front zur Kamera). */
  window.projectHotspotQuads = function(quads) {
    if (!window.scene || !window.scene.activeCamera) return JSON.stringify({});
    var cam = window.scene.activeCamera;
    var sz = canvasSize();
    var transform = window.scene.getTransformMatrix();
    var viewport = cam.viewport.toGlobal(sz.rw, sz.rh);
    var camPos = cam.globalPosition ? cam.globalPosition.clone() : cam.position.clone();
    var out = {};
    Object.keys(quads).forEach(function(id) {
      var q = quads[id];
      if (!q || !q.tl || !q.tr || !q.br || !q.bl) return;
      var tl = new BABYLON.Vector3(q.tl.x, q.tl.y, q.tl.z);
      var tr = new BABYLON.Vector3(q.tr.x, q.tr.y, q.tr.z);
      var br = new BABYLON.Vector3(q.br.x, q.br.y, q.br.z);
      var bl = new BABYLON.Vector3(q.bl.x, q.bl.y, q.bl.z);
      var pts = [tl, tr, br, bl].map(function(w){ return projectOne(w, transform, viewport, sz); });
      var minX = Math.min(pts[0].x, pts[1].x, pts[2].x, pts[3].x);
      var maxX = Math.max(pts[0].x, pts[1].x, pts[2].x, pts[3].x);
      var minY = Math.min(pts[0].y, pts[1].y, pts[2].y, pts[3].y);
      var maxY = Math.max(pts[0].y, pts[1].y, pts[2].y, pts[3].y);
      var center = tl.add(tr).add(br).add(bl).scale(0.25);
      var n = BABYLON.Vector3.Cross(tr.subtract(tl), bl.subtract(tl));
      if (n.lengthSquared() < 1e-10) n = new BABYLON.Vector3(0, 0, 1);
      else n.normalize();
      // Normale soll zur Kamera zeigen wenn Front sichtbar.
      var toCam = camPos.subtract(center).normalize();
      var facing = BABYLON.Vector3.Dot(n, toCam);
      // Falls Winding andersrum: auch |facing| mit Front-+Z vergleichen
      var frontZ = BABYLON.Vector3.Dot(n, new BABYLON.Vector3(0, 0, 1));
      if (frontZ < 0) { n = n.scale(-1); facing = -facing; }
      var depthOk = pts.every(function(p){ return p.z > -0.05 && p.z < 1.05; });
      var area = (maxX - minX) * (maxY - minY);
      var onScreen = maxX > 0 && maxY > 0 && minX < sz.cw && minY < sz.ch;
      var visible = facing > 0.12 && depthOk && onScreen && area > 8;
      out[id] = {
        left: minX / Math.max(sz.cw, 1),
        top: minY / Math.max(sz.ch, 1),
        width: (maxX - minX) / Math.max(sz.cw, 1),
        height: (maxY - minY) / Math.max(sz.ch, 1),
        visible: !!visible,
        facing: facing
      };
    });
    return JSON.stringify(out);
  };

  window.zoomAtScreen = function(sx, sy, deltaY) {
    if (!window.scene || !window.scene.activeCamera) return false;
    var cam = window.scene.activeCamera;
    var pivot = resolvePoint(sx, sy);
    var P = pivot
      ? new BABYLON.Vector3(pivot.x, pivot.y, pivot.z)
      : cam.getTarget().clone();
    var factor = deltaY > 0 ? 1.06 : 0.94;
    if (Math.abs(deltaY) > 80) factor = deltaY > 0 ? 1.10 : 0.90;

    if (cam.mode === BABYLON.Camera.ORTHOGRAPHIC_CAMERA) {
      var oldH = window._power3dOrthoHalf || cam.orthoTop || 1;
      var lo = window._power3dOrthoHalfMin || 0.03;
      var hi = window._power3dOrthoHalfMax || 4;
      var newH = Math.min(hi, Math.max(lo, oldH * factor));
      if (Math.abs(newH - oldH) < 1e-6) return false;
      var target = cam.getTarget().clone();
      var toPoint = P.subtract(target);
      var scaled = toPoint.scale(newH / oldH);
      cam.setTarget(P.subtract(scaled));
      window._power3dOrthoHalf = newH;
      if (window._power3dOrthoCamDist != null) {
        cam.radius = window._power3dOrthoCamDist;
        cam.lowerRadiusLimit = window._power3dOrthoCamDist;
        cam.upperRadiusLimit = window._power3dOrthoCamDist;
      }
      applyOrthoHalf(cam, newH);
    } else {
      var oldR = cam.radius;
      var guard = window._vendingCamGuard;
      var loR = (guard && guard.minRadius != null)
        ? guard.minRadius
        : (cam.lowerRadiusLimit != null ? cam.lowerRadiusLimit : oldR * 0.5);
      var hiR = cam.upperRadiusLimit != null ? cam.upperRadiusLimit : oldR * 5;
      var newR = Math.min(hiR, Math.max(loR, oldR * factor));
      if (Math.abs(newR - oldR) < 1e-6) return false;
      // Vor Ort zoomen — Ziel NICHT in den Schrank ziehen (Innenansichten).
      cam.radius = newR;
      cam.lowerRadiusLimit = loR;
      if (typeof window.clampVendingCamera === 'function') window.clampVendingCamera();
    }
    try { reportCameraTelemetry(true); } catch (e) {}
    return true;
  };

  window.projectWorldPoints = function(points) {
    if (!window.scene || !window.scene.activeCamera) return JSON.stringify([]);
    var cam = window.scene.activeCamera;
    var sz = canvasSize();
    var transform = window.scene.getTransformMatrix();
    var viewport = cam.viewport.toGlobal(sz.rw, sz.rh);
    var out = [];
    for (var i = 0; i < points.length; i++) {
      var p = points[i];
      var world = new BABYLON.Vector3(p.x, p.y, p.z);
      out.push(Object.assign(projectOne(world, transform, viewport, sz), {
        canvasWidth: sz.cw, canvasHeight: sz.ch
      }));
    }
    return JSON.stringify(out);
  };

  window.pickAtScreen = function(sx, sy) {
    var p = resolvePoint(sx, sy);
    if (!p) return JSON.stringify({ hit: false });
    return JSON.stringify({
      hit: true,
      point: { x: p.x, y: p.y, z: p.z },
      meshName: p.meshName,
      collectible: isCollectZoneName(p.meshName)
    });
  };

  /**
   * Entnahme-Zone: Klappe, Bay, Korb oder ausgegebenes Produkt.
   * Klappe darf den Klick nicht „schlucken“, wenn sie offen / nicht-pickable ist.
   */
  window.isOverCollectZone = function(sx, sy) {
    if (!window.scene || !window.scene.activeCamera) {
      return JSON.stringify({ over: false });
    }
    var flap = JSON.parse(window.isOverDeliveryFlap(sx, sy) || '{}');
    if (flap && flap.over) {
      return JSON.stringify({ over: true, meshName: flap.meshName, mode: 'flap' });
    }
    var sz = canvasSize();
    var rp = toRender(sx, sy, sz);
    // Ray durch alles außer Glas — Klappe optional überspringen wenn nicht pickable
    var hit = window.scene.pick(rp.x, rp.y, function(m) {
      if (!m || !m.isEnabled() || !m.isVisible) return false;
      var n = String(m.name || '');
      if (n.indexOf('Glass') >= 0 || n.indexOf('glass') >= 0) return false;
      if (n.indexOf('hotspot_') === 0) return false;
      // Offene Klappe: nicht pickable → hier nicht treffen
      if (m.isPickable === false && isFlapRelatedName(n) &&
          n.toLowerCase().indexOf('deliverybay') < 0) return false;
      return true;
    }, false);
    if (hit && hit.hit && hit.pickedMesh) {
      var pn = hit.pickedMesh.name || '';
      if (isCollectZoneName(pn) ||
          (window._dispensedProductMesh &&
           getProductUnitMeshes(window._dispensedProductMesh).indexOf(hit.pickedMesh) >= 0)) {
        return JSON.stringify({ over: true, meshName: pn, mode: 'pick' });
      }
    }
    // Ausgegebenes Produkt: Screen-Bounds (falls hinter Klappe / schlecht pickbar)
    if (window._dispensedProductMesh) {
      try {
        var parts = getProductUnitMeshes(window._dispensedProductMesh);
        var cam = window.scene.activeCamera;
        var engine = window.scene.getEngine();
        var vw = engine.getRenderWidth();
        var vh = engine.getRenderHeight();
        var transform = cam.getViewMatrix().multiply(cam.getProjectionMatrix());
        var viewport = cam.viewport.toGlobal(vw, vh);
        var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
        var any = false;
        for (var pi = 0; pi < parts.length; pi++) {
          var pm = parts[pi];
          if (!pm || !pm.isEnabled()) continue;
          pm.computeWorldMatrix(true);
          var bb = pm.getBoundingInfo().boundingBox;
          var corners = [
            bb.minimumWorld, bb.maximumWorld,
            new BABYLON.Vector3(bb.minimumWorld.x, bb.minimumWorld.y, bb.maximumWorld.z),
            new BABYLON.Vector3(bb.minimumWorld.x, bb.maximumWorld.y, bb.minimumWorld.z),
            new BABYLON.Vector3(bb.maximumWorld.x, bb.minimumWorld.y, bb.minimumWorld.z),
            new BABYLON.Vector3(bb.maximumWorld.x, bb.maximumWorld.y, bb.maximumWorld.z),
            new BABYLON.Vector3(bb.minimumWorld.x, bb.maximumWorld.y, bb.maximumWorld.z),
            new BABYLON.Vector3(bb.maximumWorld.x, bb.minimumWorld.y, bb.maximumWorld.z)
          ];
          for (var c = 0; c < corners.length; c++) {
            var sp = BABYLON.Vector3.Project(corners[c], BABYLON.Matrix.Identity(), transform, viewport);
            if (sp.x < minX) minX = sp.x;
            if (sp.y < minY) minY = sp.y;
            if (sp.x > maxX) maxX = sp.x;
            if (sp.y > maxY) maxY = sp.y;
            any = true;
          }
        }
        if (any) {
          var scaleX = sz.cw / Math.max(1, sz.rw);
          var scaleY = sz.ch / Math.max(1, sz.rh);
          minX *= scaleX; maxX *= scaleX;
          minY *= scaleY; maxY *= scaleY;
          var pad = 28;
          var over = sx >= (minX - pad) && sx <= (maxX + pad) &&
                     sy >= (minY - pad) && sy <= (maxY + pad);
          if (over) {
            return JSON.stringify({
              over: true,
              meshName: window._dispensedProductMesh.name,
              mode: 'productBounds'
            });
          }
        }
      } catch (eB) {}
    }
    return JSON.stringify({ over: false });
  };

  function isFlapRelatedName(n) {
    if (!n) return false;
    var s = String(n).toLowerCase();
    return s.indexOf('deliveryflap') >= 0 ||
      s.indexOf('deliverybay') >= 0 ||
      s.indexOf('delivery_flap') >= 0 ||
      (s.indexOf('lowerfront') >= 0 && s.indexOf('apron') >= 0) ||
      s.indexOf('flap_push') >= 0 ||
      s.indexOf('flap_door') >= 0;
  }

  function isCollectZoneName(n) {
    if (!n) return false;
    var s = String(n).toLowerCase();
    if (isFlapRelatedName(n)) return true;
    if (s.indexOf('product_') >= 0) return true;
    if (s.indexOf('elevator') >= 0 && s.indexOf('widebasket') >= 0) return true;
    if (s.indexOf('antitheft') >= 0) return true;
    if (s.indexOf('push') >= 0) return true;
    return false;
  }

  /** Klappe sichtbar lassen, aber Raycast durchlassen (Produkt dahinter anklickbar). */
  function setDeliveryFlapMeshesPickable(pickable) {
    if (!window.scene) return 0;
    var n = 0;
    var group = findDeliveryFlapDoorMeshes();
    for (var i = 0; i < group.length; i++) {
      try {
        group[i].isPickable = !!pickable;
        n++;
      } catch (e) {}
    }
    for (var mi = 0; mi < window.scene.meshes.length; mi++) {
      var m = window.scene.meshes[mi];
      if (!m || !m.name) continue;
      var low = String(m.name).toLowerCase();
      if (low.indexOf('deliveryflap') >= 0 ||
          (low.indexOf('push') >= 0 && low.indexOf('flap') >= 0)) {
        try { m.isPickable = !!pickable; n++; } catch (e2) {}
      }
    }
    return n;
  }

  window.setDeliveryFlapPickable = function(pickable) {
    var n = setDeliveryFlapMeshesPickable(!!pickable);
    return JSON.stringify({ ok: true, pickable: !!pickable, meshes: n });
  };

  /** Hover-Hit nur auf Klappe/Bay — Glas/Produkte blockieren nicht. */
  window.isOverDeliveryFlap = function(sx, sy) {
    if (!window.scene || !window.scene.activeCamera) {
      return JSON.stringify({ over: false });
    }
    var sz = canvasSize();
    var rp = toRender(sx, sy, sz);
    var hit = window.scene.pick(rp.x, rp.y, function(m) {
      if (!m || !m.isEnabled() || !m.isVisible) return false;
      return isFlapRelatedName(m.name);
    }, false);
    if (hit && hit.hit && hit.pickedMesh) {
      return JSON.stringify({ over: true, meshName: hit.pickedMesh.name, mode: 'pick' });
    }
    // Fallback: projizierte Tür-Bounds (etwas erweitert)
    var door = null;
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var m = window.scene.meshes[i];
      if (m && m.name && m.name.indexOf('DeliveryFlap_Door') >= 0) { door = m; break; }
    }
    if (!door) return JSON.stringify({ over: false });
    try {
      door.computeWorldMatrix(true);
      var bb = door.getBoundingInfo().boundingBox;
      var cam = window.scene.activeCamera;
      var engine = window.scene.getEngine();
      var vw = engine.getRenderWidth();
      var vh = engine.getRenderHeight();
      var transform = cam.getViewMatrix().multiply(cam.getProjectionMatrix());
      var viewport = cam.viewport.toGlobal(vw, vh);
      var corners = [
        bb.minimumWorld,
        bb.maximumWorld,
        new BABYLON.Vector3(bb.minimumWorld.x, bb.minimumWorld.y, bb.maximumWorld.z),
        new BABYLON.Vector3(bb.minimumWorld.x, bb.maximumWorld.y, bb.minimumWorld.z),
        new BABYLON.Vector3(bb.maximumWorld.x, bb.minimumWorld.y, bb.minimumWorld.z),
        new BABYLON.Vector3(bb.maximumWorld.x, bb.maximumWorld.y, bb.maximumWorld.z),
        new BABYLON.Vector3(bb.minimumWorld.x, bb.maximumWorld.y, bb.maximumWorld.z),
        new BABYLON.Vector3(bb.maximumWorld.x, bb.minimumWorld.y, bb.maximumWorld.z)
      ];
      var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
      for (var c = 0; c < corners.length; c++) {
        var sp = BABYLON.Vector3.Project(corners[c], BABYLON.Matrix.Identity(), transform, viewport);
        if (sp.x < minX) minX = sp.x;
        if (sp.y < minY) minY = sp.y;
        if (sp.x > maxX) maxX = sp.x;
        if (sp.y > maxY) maxY = sp.y;
      }
      // Render → CSS-Pixel
      var scaleX = sz.cw / Math.max(1, sz.rw);
      var scaleY = sz.ch / Math.max(1, sz.rh);
      minX *= scaleX; maxX *= scaleX;
      minY *= scaleY; maxY *= scaleY;
      var padX = (maxX - minX) * 0.35 + 18;
      var padY = (maxY - minY) * 0.55 + 22;
      var over = sx >= (minX - padX) && sx <= (maxX + padX) &&
                 sy >= (minY - padY) && sy <= (maxY + padY);
      return JSON.stringify({ over: !!over, meshName: door.name, mode: 'bounds' });
    } catch (e) {
      return JSON.stringify({ over: false, error: String(e) });
    }
  };

  /** Alle Meshes der PUSH-Klappe (Door + ggf. abgespaltene Push-Primitives). */
  function findDeliveryFlapDoorMeshes() {
    if (!window.scene) return [];
    var doors = [];
    var extras = [];
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var m = window.scene.meshes[i];
      if (!m || !m.name) continue;
      var n = m.name;
      if (n.indexOf('DeliveryFlap_Door') >= 0) {
        doors.push(m);
        continue;
      }
      // Abgespaltene PUSH-Lettering-Meshes (nach Flat-Shade / MultiMaterial-Split)
      var isPushName = n.toLowerCase().indexOf('push') >= 0 &&
        (n.indexOf('Flap') >= 0 || n.indexOf('Delivery') >= 0);
      var matPush = false;
      try {
        var mat = m.material;
        var mats = mat ? (mat.subMaterials || [mat]) : [];
        for (var mi = 0; mi < mats.length; mi++) {
          if (mats[mi] && mats[mi].name && String(mats[mi].name).indexOf('Push') >= 0) {
            matPush = true; break;
          }
        }
      } catch (eM) {}
      if (isPushName || matPush) extras.push(m);
    }
    // Primäre Door zuerst
    doors.sort(function(a, b) {
      var ae = a.name.indexOf('Vending_DeliveryFlap_Door') >= 0 ? 0 : 1;
      var be = b.name.indexOf('Vending_DeliveryFlap_Door') >= 0 ? 0 : 1;
      return ae - be;
    });
    return doors.concat(extras);
  }

  function attachPushMeshesToDoor(door) {
    if (!door || !window.scene) return;
    door.computeWorldMatrix(true);
    var dbb = door.getBoundingInfo().boundingBox;
    var dCenter = BABYLON.Vector3.Center(dbb.minimumWorld, dbb.maximumWorld);
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var m = window.scene.meshes[i];
      if (!m || m === door || !m.name) continue;
      var n = m.name.toLowerCase();
      var matPush = false;
      try {
        var mat = m.material;
        var mats = mat ? (mat.subMaterials || [mat]) : [];
        for (var mi = 0; mi < mats.length; mi++) {
          if (mats[mi] && mats[mi].name && String(mats[mi].name).indexOf('Push') >= 0) {
            matPush = true; break;
          }
        }
      } catch (e) {}
      var nameHit = (n.indexOf('push') >= 0 && (n.indexOf('flap') >= 0 || n.indexOf('delivery') >= 0));
      if (!matPush && !nameHit) continue;
      // Nur nahe der Tür (nicht CoinReturn etc.)
      try {
        m.computeWorldMatrix(true);
        var c = m.getBoundingInfo().boundingBox.centerWorld;
        if (BABYLON.Vector3.Distance(c, dCenter) > 0.55) continue;
      } catch (e2) { continue; }
      if (m.parent === door) continue;
      try {
        m.setParent(door);
        m._flapPushAttached = true;
      } catch (e3) {}
    }
  }

  window.setDeliveryFlapOpen = function(open, angleDeg) {
    if (!window.scene) return JSON.stringify({ ok: false, error: 'no scene' });
    var scene = window.scene;
    var group = findDeliveryFlapDoorMeshes();
    var mesh = group.length ? group[0] : null;
    if (!mesh) return JSON.stringify({ ok: false, error: 'door not found' });

    mesh.setEnabled(true);
    mesh.isVisible = true;
    mesh.visibility = 1.0;
    attachPushMeshesToDoor(mesh);

    // Alte Hinge-Parenting-Bugs rückgängig.
    if (mesh._flapHinge) {
      try {
        mesh.setParent(null);
        mesh._flapHinge.dispose();
      } catch (eH) {}
      mesh._flapHinge = null;
      try {
        mesh.position.set(0, 0, 0);
        mesh.rotation.set(0, 0, 0);
        mesh.rotationQuaternion = null;
        mesh.setPivotMatrix(BABYLON.Matrix.Identity());
        mesh.computeWorldMatrix(true);
      } catch (eR) {}
      mesh._flapPivotReady = false;
    }

    // Pivot am OBEREN Türrand — Unterkante schwingt NACH INNEN (in die Bay).
    if (!mesh._flapPivotReady) {
      mesh.computeWorldMatrix(true);
      try { mesh.refreshBoundingInfo(); } catch (eB) {}
      var bb = mesh.getBoundingInfo().boundingBox;
      // glTF: Höhe = Y, Front ≈ ±Z. Scharnier oben (max Y), Mitte X/Z.
      var pivot = new BABYLON.Vector3(
        (bb.minimum.x + bb.maximum.x) * 0.5,
        bb.maximum.y,
        (bb.minimum.z + bb.maximum.z) * 0.5
      );
      try {
        mesh.setPivotPoint(pivot, BABYLON.Space.LOCAL);
      } catch (eP) {
        mesh.setPivotMatrix(BABYLON.Matrix.Translation(-pivot.x, -pivot.y, -pivot.z));
      }
      mesh._flapClosedRotX = 0;
      mesh.rotation.x = 0;
      mesh._flapPivotReady = true;
      mesh._flapAngle = 0;
    }

    var deg = (typeof angleDeg === 'number' && isFinite(angleDeg)) ? angleDeg : 48;
    if (deg > 75) deg = 75;
    if (deg < 10) deg = 10;
    // Positives X: Unterkante nach hinten/innen in die Ausgabe (nicht zum Betrachter).
    var rad = deg * Math.PI / 180;
    var target = open ? rad : 0;
    mesh._flapTargetOpen = !!open;

    // Offen: Klappe bleibt sichtbar, ist aber nicht pickable → Produkt/Bay dahinter anklickbar.
    setDeliveryFlapMeshesPickable(!open);

    if (mesh._flapAnim) {
      try { scene.onBeforeRenderObservable.remove(mesh._flapAnim); } catch (e) {}
      mesh._flapAnim = null;
    }
    mesh._flapAnim = scene.onBeforeRenderObservable.add(function() {
      var cur = mesh.rotation.x;
      var next = cur + (target - cur) * 0.30;
      if (Math.abs(target - next) < 0.001) {
        mesh.rotation.x = target;
        mesh._flapAngle = target;
        try { scene.onBeforeRenderObservable.remove(mesh._flapAnim); } catch (e2) {}
        mesh._flapAnim = null;
        try { setDeliveryFlapMeshesPickable(!mesh._flapTargetOpen); } catch (eP) {}
      } else {
        mesh.rotation.x = next;
        mesh._flapAngle = next;
      }
      mesh.setEnabled(true);
      mesh.isVisible = true;
      mesh.visibility = 1.0;
    });

    return JSON.stringify({
      ok: true,
      open: !!open,
      mesh: mesh.name,
      attached: group.length,
      hinge: 'pivotLocalInward',
      angleDeg: deg,
      pickable: !open
    });
  };

  /** Klappe auf Bake-Pose zurück (keine Schleuder-Geister auf Regalhöhe). */
  window.resetDeliveryFlapHome = function() {
    if (!window.scene) return JSON.stringify({ ok: false });
    var n = 0;
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var mesh = window.scene.meshes[i];
      if (!mesh || !mesh.name) continue;
      if (mesh.name.indexOf('DeliveryFlap_Door') < 0) continue;
      try {
        if (mesh._flapAnim) {
          window.scene.onBeforeRenderObservable.remove(mesh._flapAnim);
          mesh._flapAnim = null;
        }
        if (mesh._flapHinge) {
          mesh.setParent(null);
          try { mesh._flapHinge.dispose(); } catch (eD) {}
          mesh._flapHinge = null;
        }
        mesh.position.set(0, 0, 0);
        mesh.rotation.set(0, 0, 0);
        mesh.rotationQuaternion = null;
        mesh.setPivotMatrix(BABYLON.Matrix.Identity());
        mesh._flapPivotReady = false;
        mesh._flapAngle = 0;
        mesh.computeWorldMatrix(true);
        n++;
      } catch (e) {}
    }
    return JSON.stringify({ ok: true, reset: n });
  };

  /**
   * AntiTheft_Flap: geschlossene GLB-Pose = Diebstahlschutz zu.
   * Blender Action: location.y -0.305 → +0.097 (einfahren).
   * glTF Y-up: Blender +Y → Babylon −Z ⇒ Retract Δz ≈ −0.40.
   */
  var ANTITHEFT_RETRACT_Z = -0.402;

  function findAntiTheftFlapMeshes() {
    if (!window.scene) return [];
    var out = [];
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var m = window.scene.meshes[i];
      if (!m || !m.name) continue;
      if (/AntiTheft_Flap/i.test(m.name) && !/SlotLiner/i.test(m.name)) out.push(m);
    }
    return out;
  }

  function ensureAntiTheftVisible() {
    var meshes = findAntiTheftFlapMeshes();
    for (var i = 0; i < meshes.length; i++) {
      var mesh = meshes[i];
      try {
        mesh.setEnabled(true);
        mesh.isVisible = true;
        mesh.visibility = 1.0;
        mesh.renderingGroupId = 0;
        mesh.isPickable = false;
        if (!mesh._antiTheftHomePos) mesh._antiTheftHomePos = mesh.position.clone();
      } catch (e) {}
    }
    for (var j = 0; j < window.scene.meshes.length; j++) {
      var sl = window.scene.meshes[j];
      if (!sl || !sl.name || !/AntiTheft_SlotLiner/i.test(sl.name)) continue;
      try {
        sl.setEnabled(true);
        sl.isVisible = true;
        sl.visibility = 1.0;
      } catch (e2) {}
    }
    return meshes;
  }

  window.resetAntiTheftHome = function() {
    if (!window.scene) return JSON.stringify({ ok: false });
    var meshes = ensureAntiTheftVisible();
    for (var i = 0; i < meshes.length; i++) {
      var mesh = meshes[i];
      try {
        if (mesh._antiTheftAnim) {
          window.scene.onBeforeRenderObservable.remove(mesh._antiTheftAnim);
          mesh._antiTheftAnim = null;
        }
        if (!mesh._antiTheftHomePos) mesh._antiTheftHomePos = mesh.position.clone();
        mesh.position.copyFrom(mesh._antiTheftHomePos);
        mesh._antiTheftRetracted = false;
      } catch (e) {}
    }
    return JSON.stringify({ ok: true, meshes: meshes.map(function(m) { return m.name; }) });
  };

  /** retracted=true: Klappe einfahren (Durchlass); false: wieder verschließen. */
  window.setAntiTheftRetracted = function(retracted, durationMs) {
    if (!window.scene) return JSON.stringify({ ok: false });
    var meshes = ensureAntiTheftVisible();
    if (!meshes.length) return JSON.stringify({ ok: false, error: 'no AntiTheft_Flap' });
    var dur = Math.max(80, durationMs || 280);
    var want = !!retracted;
    for (var i = 0; i < meshes.length; i++) {
      (function(mesh) {
        if (!mesh._antiTheftHomePos) mesh._antiTheftHomePos = mesh.position.clone();
        var home = mesh._antiTheftHomePos;
        var targetZ = home.z + (want ? ANTITHEFT_RETRACT_Z : 0);
        var start = mesh.position.clone();
        var end = new BABYLON.Vector3(home.x, home.y, targetZ);
        if (mesh._antiTheftAnim) {
          try { window.scene.onBeforeRenderObservable.remove(mesh._antiTheftAnim); } catch (e) {}
          mesh._antiTheftAnim = null;
        }
        var t0 = Date.now();
        mesh._antiTheftAnim = window.scene.onBeforeRenderObservable.add(function() {
          var u = Math.min(1, (Date.now() - t0) / dur);
          var ease = u * u * (3 - 2 * u);
          mesh.position.x = start.x + (end.x - start.x) * ease;
          mesh.position.y = start.y + (end.y - start.y) * ease;
          mesh.position.z = start.z + (end.z - start.z) * ease;
          if (u >= 1) {
            try { window.scene.onBeforeRenderObservable.remove(mesh._antiTheftAnim); } catch (e2) {}
            mesh._antiTheftAnim = null;
            mesh._antiTheftRetracted = want;
          }
        });
      })(meshes[i]);
    }
    return JSON.stringify({ ok: true, retracted: want, meshes: meshes.length, durationMs: dur });
  };

  function setAntiTheftRetractedAsync(retracted, durationMs) {
    return new Promise(function(resolve) {
      var res = window.setAntiTheftRetracted(retracted, durationMs);
      var parsed = null;
      try { parsed = JSON.parse(res); } catch (e) {}
      var wait = (parsed && parsed.durationMs) ? parsed.durationMs : (durationMs || 280);
      setTimeout(function() { resolve(parsed && parsed.ok); }, wait + 20);
    });
  }

  function parseProductMeshName(name) {
    if (!name) return null;
    var m = String(name).match(/Product_([A-F])(\d{2})_s(\d+)/i);
    if (!m) return null;
    return {
      row: m[1].toUpperCase(),
      col: parseInt(m[2], 10),
      stack: parseInt(m[3], 10),
      slot: m[1].toUpperCase() + String(parseInt(m[2], 10))
    };
  }

  function isProductMeshName(nm) {
    return !!(nm && nm.indexOf('Product_') >= 0);
  }

  /** true bei Flasche/Dose (MultiMaterial PET/Label/Cap) — höherer Fall nötig. */
  function isDrinkProductMesh(mesh) {
    if (!mesh) return false;
    var info = parseProductMeshName(mesh.name);
    if (info && (info.row === 'A' || info.row === 'B')) return true;
    var mats = [];
    if (mesh.material) {
      mats = mesh.material.subMaterials && mesh.material.subMaterials.length
        ? mesh.material.subMaterials
        : [mesh.material];
    }
    for (var i = 0; i < mats.length; i++) {
      var n = ((mats[i] && mats[i].name) || '').toLowerCase();
      if (n.indexOf('pet') >= 0 || n.indexOf('cap') >= 0 || n.indexOf('can') >= 0 ||
          n.indexOf('bottle') >= 0 || n.indexOf('label') >= 0) return true;
    }
    return false;
  }

  // Soft-Defaults / Caps — Ziel wird aus Produkt-Unterkante berechnet.
  // A/B (Flaschen) brauchen mehr Hub: Caps müssen über bot−clearance−floorTop liegen
  // (gemessen final_v004: A≈1.44, B≈1.18 bei clearance 0.14).
  var ELEVATOR_ROW_DELTA_Y = {
    A: 1.52, B: 1.26, C: 0.88, D: 0.68, E: 0.48, F: 0.28
  };

  /** Nur der fahrende Korb — Schienen/Gurte bleiben am Gehäuse. */
  function isElevatorMeshName(nm) {
    if (!nm) return false;
    // Alter eckiger Runtime-Fallback — nie mitanimieren / nie anzeigen.
    if (/WideBasket_Runtime/i.test(nm)) return false;
    if (nm.indexOf('Elevator_') < 0 && nm.indexOf('elevator_') < 0) return false;
    if (nm.indexOf('Zone') >= 0 || nm.indexOf('Parking') >= 0) return false;
    if (/WideBasket/i.test(nm)) return true;
    return false;
  }

  /** Entfernt den alten CreateBox-Korb, sobald der GLB-Korb da ist. */
  function disposeRuntimeElevatorBasket() {
    if (!window.scene) return;
    var doomed = [];
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var m = window.scene.meshes[i];
      if (m && m.name && /WideBasket_Runtime/i.test(m.name)) doomed.push(m);
    }
    for (var d = 0; d < doomed.length; d++) {
      try {
        if (window._saElevatorBasket === doomed[d]) window._saElevatorBasket = null;
        doomed[d].dispose();
      } catch (eDisp) {}
    }
  }

  function listElevatorMeshes() {
    if (!window.scene) return [];
    var all = [];
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var mesh = window.scene.meshes[i];
      if (!mesh || !isElevatorMeshName(mesh.name)) continue;
      all.push(mesh);
    }
    // Transform-Nodes (leerer WideBasket-Parent) auch berücksichtigen.
    try {
      var nodes = window.scene.transformNodes || [];
      for (var ti = 0; ti < nodes.length; ti++) {
        var tn = nodes[ti];
        if (!tn || !isElevatorMeshName(tn.name)) continue;
        if (all.indexOf(tn) < 0) all.push(tn);
      }
    } catch (eNodes) {}
    if (window._saElevatorBasket && all.indexOf(window._saElevatorBasket) < 0) {
      all.push(window._saElevatorBasket);
    }
    // Nur Wurzel bewegen — Floor/Wall als Kinder nie separat (sonst klaffen sie auseinander).
    var out = [];
    for (var ai = 0; ai < all.length; ai++) {
      var m = all[ai];
      var p = m.parent;
      var nested = false;
      while (p) {
        if (all.indexOf(p) >= 0 || (p.name && /WideBasket$/i.test(p.name))) {
          nested = true;
          break;
        }
        p = p.parent;
      }
      if (!nested) out.push(m);
    }
    // Falls Floor+Wall als getrennte Wurzeln existieren: nur Floor bewegen
    // und Wall fest an Floor koppeln (Legacy-GLB ohne Join).
    if (out.length > 1) {
      var floorRoot = null;
      var wallRoot = null;
      var other = [];
      for (var oi = 0; oi < out.length; oi++) {
        var on = out[oi].name || '';
        if (/WideBasket_Floor/i.test(on)) floorRoot = out[oi];
        else if (/WideBasket_Wall/i.test(on)) wallRoot = out[oi];
        else other.push(out[oi]);
      }
      if (floorRoot && wallRoot) {
        try {
          if (wallRoot.parent !== floorRoot) {
            wallRoot.setParent(floorRoot);
          }
        } catch (eParent) {}
        out = other.concat([floorRoot]);
      }
    }
    return out.length ? out : all;
  }

  function captureElevatorHome(force) {
    if (!window.scene) return 0;
    var meshes = listElevatorMeshes();
    var n = 0;
    for (var i = 0; i < meshes.length; i++) {
      var mesh = meshes[i];
      if (force || !mesh._elevHomePos) {
        mesh._elevHomePos = mesh.position.clone();
      }
      n++;
    }
    window._elevatorHomeReady = true;
    return n;
  }

  function showElevatorBasket(mesh, visible) {
    if (!mesh) return;
    try {
      mesh.setEnabled(!!visible);
      mesh.isVisible = !!visible;
      mesh.visibility = visible ? 1.0 : 0.0;
      if (visible) {
        mesh.renderingGroupId = 1;
        mesh.isPickable = false;
      }
    } catch (e) {}
  }

  /**
   * Moderner GLB-Korb (Floor/Wall, auch als `_EXP_Elevator_WideBasket_*`).
   * Kein CreateBox-Fallback mehr — der eckige Runtime-Korb lag sonst über dem echten.
   */
  function ensureElevatorBasket() {
    if (!window.scene) return null;
    disposeRuntimeElevatorBasket();
    if (window._saElevatorBasket && !window._saElevatorBasket.isDisposed &&
        window._saElevatorBasket.name &&
        /WideBasket/i.test(window._saElevatorBasket.name) &&
        !/WideBasket_Runtime/i.test(window._saElevatorBasket.name)) {
      showElevatorBasket(window._saElevatorBasket, true);
      return window._saElevatorBasket;
    }
    window._saElevatorBasket = null;

    // Bevorzuge Floor (Tray), dann Wall, dann beliebigen WideBasket — überall matchen,
    // damit `_EXP_Elevator_WideBasket_Floor` aus dem Blender-Export gefunden wird.
    var preferredRe = [
      /WideBasket_Floor/i,
      /WideBasket_Wall/i,
      /WideBasket(?!_Runtime)/i
    ];
    var found = null;
    for (var n = 0; n < preferredRe.length && !found; n++) {
      for (var i = 0; i < window.scene.meshes.length; i++) {
        var m = window.scene.meshes[i];
        if (m && m.name && preferredRe[n].test(m.name)) {
          found = m;
          break;
        }
      }
      if (!found) {
        try {
          var nodes = window.scene.transformNodes || [];
          for (var ti = 0; ti < nodes.length; ti++) {
            var tn = nodes[ti];
            if (tn && tn.name && preferredRe[n].test(tn.name)) {
              found = tn;
              break;
            }
          }
        } catch (eTn) {}
      }
    }
    // Falls Floor gefunden aber Parent WideBasket existiert → Parent nutzen
    if (found && found.parent && found.parent.name && /WideBasket$/i.test(found.parent.name)) {
      found = found.parent;
    }
    if (found) {
      showElevatorBasket(found, true);
      try {
        var wallKids = found.getChildMeshes ? found.getChildMeshes(false) : [];
        for (var wi = 0; wi < wallKids.length; wi++) {
          if (wallKids[wi].name && /WideBasket_(Wall|Floor)/i.test(wallKids[wi].name)) {
            showElevatorBasket(wallKids[wi], true);
          }
        }
      } catch (eShow) {}
      // Floor+Wall als getrennte Wurzeln: Wall an Floor koppeln
      try {
        var floorM = null;
        var wallM = null;
        for (var si = 0; si < window.scene.meshes.length; si++) {
          var sm = window.scene.meshes[si];
          if (!sm || !sm.name) continue;
          if (/WideBasket_Floor/i.test(sm.name)) floorM = sm;
          else if (/WideBasket_Wall/i.test(sm.name)) wallM = sm;
        }
        if (floorM && wallM && wallM.parent !== floorM) {
          wallM.setParent(floorM);
          found = floorM;
        }
      } catch (eJoin) {}
      window._saElevatorBasket = found;
      if (!found._elevHomePos) found._elevHomePos = found.position.clone();
      return found;
    }
    return null;
  }

  function animateElevatorDeltaY(deltaY, durationMs) {
    return new Promise(function(resolve) {
      if (!window.scene) { resolve(false); return; }
      ensureElevatorBasket();
      captureElevatorHome();
      var meshes = listElevatorMeshes();
      if (!meshes.length) { resolve(false); return; }
      for (var s = 0; s < meshes.length; s++) showElevatorBasket(meshes[s], true);
      var dur = Math.max(180, durationMs || 700);
      var t0 = Date.now();
      var starts = meshes.map(function(m) { return m.position.y; });
      var ends = meshes.map(function(m) {
        return (m._elevHomePos ? m._elevHomePos.y : m.position.y) + deltaY;
      });
      if (window._elevatorAnimObs) {
        try { window.scene.onBeforeRenderObservable.remove(window._elevatorAnimObs); } catch (e) {}
        window._elevatorAnimObs = null;
      }
      window._elevatorAnimObs = window.scene.onBeforeRenderObservable.add(function() {
        var u = Math.min(1, (Date.now() - t0) / dur);
        var ease = u * u * (3 - 2 * u);
        for (var i = 0; i < meshes.length; i++) {
          meshes[i].position.y = starts[i] + (ends[i] - starts[i]) * ease;
        }
        if (u >= 1) {
          try { window.scene.onBeforeRenderObservable.remove(window._elevatorAnimObs); } catch (e2) {}
          window._elevatorAnimObs = null;
          resolve(true);
        }
      });
    });
  }

  window.resetElevatorHome = function() {
    if (!window.scene) return JSON.stringify({ ok: false });
    ensureElevatorBasket();
    var n = captureElevatorHome();
    var meshes = listElevatorMeshes();
    for (var i = 0; i < meshes.length; i++) {
      var mesh = meshes[i];
      if (!mesh || !mesh._elevHomePos) continue;
      mesh.position.copyFrom(mesh._elevHomePos);
      showElevatorBasket(mesh, true);
    }
    return JSON.stringify({ ok: true, meshes: n });
  };

  window.isDispenseComplete = function() {
    return JSON.stringify({
      done: window._dispenseBusy ? false : (window._dispenseDone !== false),
      busy: !!window._dispenseBusy,
      slot: window._dispensedSlot || null
    });
  };
  if (typeof window._dispenseDone === 'undefined') window._dispenseDone = true;
  if (typeof window._dispenseBusy === 'undefined') window._dispenseBusy = false;

  /** Sichtbarkeit + Branding erhalten (Label/Cap/PET zusammen, Texturen nicht killen). */
  function forceShowDispensingProduct(mesh) {
    if (!mesh) return;
    var parts = getProductUnitMeshes(mesh);
    for (var pi = 0; pi < parts.length; pi++) {
      forceShowOneProductMesh(parts[pi]);
    }
  }

  function forceShowOneProductMesh(mesh) {
    if (!mesh) return;
    try {
      mesh.setEnabled(true);
      mesh.isVisible = true;
      mesh.visibility = 1.0;
      mesh.isPickable = true;
      // Depth mit Gehäuse teilen — nie Gruppe 2 (sonst „durchscheinen“).
      mesh.renderingGroupId = 0;
      mesh.alwaysSelectAsActiveMesh = false;
      if (mesh.alphaIndex !== undefined) mesh.alphaIndex = 0;
      var mats = [];
      if (mesh.material) {
        mats = mesh.material.subMaterials && mesh.material.subMaterials.length
          ? mesh.material.subMaterials
          : [mesh.material];
      }
      for (var i = 0; i < mats.length; i++) {
        var mat = mats[i];
        if (!mat) continue;
        // Glow aus
        try {
          if (mat.emissiveColor) mat.emissiveColor = new BABYLON.Color3(0, 0, 0);
          if (mat.emissiveIntensity !== undefined) mat.emissiveIntensity = 0;
        } catch (eEm) {}
        // Getränke-PET/Label/Cap: HASHED/BLEND → sonst unsichtbar hinter Glas während Fall
        var mn = (mat.name || '').toLowerCase();
        var isDrinkMat = mn.indexOf('pet') >= 0 || mn.indexOf('_cap') >= 0 ||
          mn.indexOf('label') >= 0 || mn.indexOf('can') >= 0 || mn.indexOf('bottle') >= 0;
        if (mat.alpha !== undefined && (mat.alpha < 0.99 || isDrinkMat)) {
          mat.alpha = 1.0;
        }
        try { mat.transparencyMode = BABYLON.Material.MATERIAL_OPAQUE; } catch (eT) {}
        try { mat.transparencyMode = BABYLON.PBRMaterial.PBRMATERIAL_OPAQUE; } catch (eT2) {}
        if (mat.forceDepthWrite !== undefined) mat.forceDepthWrite = true;
        if (isDrinkMat && mat.roughness !== undefined) {
          mat.roughness = Math.max(mat.roughness || 0, 0.22);
        }
      }
      mesh._saProductMatFixed = true;
    } catch (e) {}
  }

  function findGltfRoot() {
    if (!window.scene) return null;
    if (window._saGltfRoot && !window._saGltfRoot.isDisposed) return window._saGltfRoot;
    var nodes = [];
    try {
      if (window.scene.meshes) nodes = nodes.concat(window.scene.meshes);
      if (window.scene.transformNodes) nodes = nodes.concat(window.scene.transformNodes);
      if (window.scene.rootNodes) nodes = nodes.concat(window.scene.rootNodes);
    } catch (e) {}
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      if (n && n.name === '__root__') {
        window._saGltfRoot = n;
        return n;
      }
    }
    return null;
  }

  /**
   * Home-Pose sichern. GLB-Bake: lokal Identity unter __root__.
   * NIEMALS setParent(null) ohne Re-Parent — sonst weg mit Y-up-Rotation.
   */
  function captureMeshHome(mesh, force) {
    if (!mesh) return;
    if (mesh._saHome && !force) return;
    try {
      // Vor dem ersten Capture: Bake-Pose erzwingen (repariert alte Unparent-Bugs)
      ensureShelfMeshUnderRoot(mesh);
      mesh.computeWorldMatrix(true);
      var center = meshWorldCenter(mesh);
      var axis = new BABYLON.Vector3(1, 0, 0);
      try {
        var bb = mesh.getBoundingInfo().boundingBox;
        var size = bb.maximumWorld.subtract(bb.minimumWorld);
        if (size.x >= size.y && size.x >= size.z) axis = new BABYLON.Vector3(1, 0, 0);
        else if (size.y >= size.x && size.y >= size.z) axis = new BABYLON.Vector3(0, 1, 0);
        else axis = new BABYLON.Vector3(0, 0, 1);
      } catch (eA) {}
      mesh._saHome = {
        pos: new BABYLON.Vector3(0, 0, 0),
        rot: new BABYLON.Vector3(0, 0, 0),
        quat: null,
        scl: new BABYLON.Vector3(1, 1, 1),
        pivot: BABYLON.Matrix.Identity(),
        center: center ? center.clone() : null,
        axis: axis
      };
    } catch (e) {}
  }

  /** Produkt/Spirale unter __root__ + lokale Identity (Bake). */
  function ensureShelfMeshUnderRoot(mesh) {
    if (!mesh) return;
    var root = findGltfRoot();
    try {
      if (root && mesh.parent !== root) {
        // Erst World halten, dann Identity unter Root = korrekte Bake-Lage
        try { mesh.setParent(root, true); } catch (e1) {
          try { mesh.parent = root; } catch (e2) {}
        }
      }
      mesh.position.set(0, 0, 0);
      mesh.rotation.set(0, 0, 0);
      mesh.rotationQuaternion = null;
      mesh.scaling.set(1, 1, 1);
      try { mesh.setPivotMatrix(BABYLON.Matrix.Identity()); } catch (eP) {}
      mesh.computeWorldMatrix(true);
    } catch (e) {}
  }

  function restoreMeshHome(mesh) {
    if (!mesh) return;
    try {
      ensureShelfMeshUnderRoot(mesh);
      if (!mesh._saHome) captureMeshHome(mesh, true);
      var h = mesh._saHome;
      if (h && h.center) {
        // Center nach Identity neu messen falls noch nicht gesetzt
      }
      mesh.computeWorldMatrix(true);
    } catch (e) {}
  }

  function isSpiralMeshName(nm) {
    return !!(nm && /Motor_.*_Spiral/i.test(nm));
  }

  function captureAllShelfHomes(force) {
    if (!window.scene) return 0;
    var skip = {};
    if (window._dispensedProductMesh) {
      try {
        var dparts = getProductUnitMeshes(window._dispensedProductMesh);
        for (var d = 0; d < dparts.length; d++) skip[dparts[d].uniqueId] = true;
      } catch (e) {}
    }
    var n = 0;
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var mesh = window.scene.meshes[i];
      if (!mesh || !mesh.name) continue;
      if (skip[mesh.uniqueId]) continue;
      if (!isProductMeshName(mesh.name) && !isSpiralMeshName(mesh.name)) continue;
      captureMeshHome(mesh, !!force);
      n++;
    }
    window._saShelfHomesReady = true;
    return n;
  }

  /** Regal-Pose wiederherstellen — ohne Parent-Wechsel. */
  function resetProductBakePose(mesh) {
    if (!mesh) return;
    var parts = getProductUnitMeshes(mesh);
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i];
      restoreMeshHome(p);
      try {
        p.renderingGroupId = 0;
        p.alwaysSelectAsActiveMesh = false;
      } catch (e2) {}
    }
  }

  function resetAllSpiralHomes() {
    if (!window.scene) return 0;
    var n = 0;
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var mesh = window.scene.meshes[i];
      if (!mesh || !isSpiralMeshName(mesh.name)) continue;
      restoreMeshHome(mesh);
      n++;
    }
    return n;
  }

  function resetAllShelfProductPoses() {
    if (!window.scene) return 0;
    if (!window._saShelfHomesReady) captureAllShelfHomes(false);
    var n = 0;
    var seen = {};
    var skip = {};
    if (window._dispensedProductMesh) {
      var dparts = getProductUnitMeshes(window._dispensedProductMesh);
      for (var d = 0; d < dparts.length; d++) skip[dparts[d].uniqueId] = true;
    }
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var mesh = window.scene.meshes[i];
      if (!mesh || !mesh.name || !isProductMeshName(mesh.name)) continue;
      if (skip[mesh.uniqueId]) continue;
      var info = parseProductMeshName(mesh.name);
      if (!info) continue;
      var key = info.slot + '_s' + info.stack;
      if (seen[key]) continue;
      seen[key] = true;
      resetProductBakePose(mesh);
      n++;
    }
    try { resetAllSpiralHomes(); } catch (eS) {}
    return n;
  }

  /** Alle Produkt-Meshes: Glow zurücksetzen (nach fehlgeschlagenen Dispense-Versuchen). */
  function resetAllProductGlow() {
    if (!window.scene) return;
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var mesh = window.scene.meshes[i];
      if (!mesh || !mesh.name || !isProductMeshName(mesh.name)) continue;
      mesh._saProductMatFixed = false;
      try {
        var mats = mesh.material
          ? (mesh.material.subMaterials && mesh.material.subMaterials.length
              ? mesh.material.subMaterials
              : [mesh.material])
          : [];
        for (var mi = 0; mi < mats.length; mi++) {
          var mat = mats[mi];
          if (!mat) continue;
          if (mat.emissiveColor) mat.emissiveColor = new BABYLON.Color3(0, 0, 0);
          if (mat.emissiveIntensity !== undefined) mat.emissiveIntensity = 0;
        }
        mesh.renderingGroupId = 0;
        mesh.alwaysSelectAsActiveMesh = false;
      } catch (e) {}
    }
  }

  /**
   * Alle Mesh-Teile einer Produkt-Einheit (PET+Label+Cap nach MultiMaterial-Split).
   * Akzeptiert auch `_EXP_Product_A01_s00` / `…_primitive0` / `….001`.
   */
  function getProductUnitMeshes(seedMesh) {
    if (!seedMesh || !seedMesh.name || !window.scene) return seedMesh ? [seedMesh] : [];
    var info = parseProductMeshName(seedMesh.name);
    if (!info) return [seedMesh];
    var colPad = (info.col < 10 ? '0' : '') + String(info.col);
    var stackPad = (info.stack < 10 ? '0' : '') + String(info.stack);
    var prefix = 'Product_' + info.row + colPad + '_s' + stackPad;
    var out = [];
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var m = window.scene.meshes[i];
      if (!m || !m.name) continue;
      var idx = m.name.indexOf(prefix);
      if (idx < 0) continue;
      var after = m.name.substring(idx + prefix.length);
      // Exakt oder Suffix von Split/Clone — nicht Product_A01_s00x
      if (after !== '' && !/^[._]/.test(after) && !/^prim/i.test(after)) continue;
      out.push(m);
    }
    if (!out.length) out.push(seedMesh);
    // Kinder derselben Einheit (MultiMaterial-Split unter Parent)
    try {
      for (var j = 0; j < out.length; j++) {
        var kids = out[j].getChildMeshes ? out[j].getChildMeshes(false) : [];
        for (var k = 0; k < kids.length; k++) {
          if (out.indexOf(kids[k]) < 0) out.push(kids[k]);
        }
      }
    } catch (eCh) {}
    return out;
  }

  /** Gemeinsame Welt-BBox aller Teile. */
  function productUnitWorldBounds(seedMesh) {
    var parts = getProductUnitMeshes(seedMesh);
    var min = new BABYLON.Vector3(1e9, 1e9, 1e9);
    var max = new BABYLON.Vector3(-1e9, -1e9, -1e9);
    var any = false;
    for (var i = 0; i < parts.length; i++) {
      try {
        parts[i].computeWorldMatrix(true);
        var bb = parts[i].getBoundingInfo().boundingBox;
        min = BABYLON.Vector3.Minimize(min, bb.minimumWorld);
        max = BABYLON.Vector3.Maximize(max, bb.maximumWorld);
        any = true;
      } catch (e) {}
    }
    if (!any) return null;
    return { min: min, max: max, center: BABYLON.Vector3.Center(min, max) };
  }

  /** Alle Teile um denselben Welt-Delta verschieben (Branding bleibt zusammen). */
  function moveProductUnitBy(seedMesh, delta) {
    var parts = getProductUnitMeshes(seedMesh);
    for (var i = 0; i < parts.length; i++) {
      parts[i].position.addInPlace(delta);
      forceShowOneProductMesh(parts[i]);
    }
  }

  function animateProductUnitToCenter(seedMesh, targetWorldCenter, durationMs, easeIn) {
    return new Promise(function(resolve) {
      if (!seedMesh || !window.scene) { resolve(false); return; }
      var bounds = productUnitWorldBounds(seedMesh);
      if (!bounds) { resolve(false); return; }
      var delta = targetWorldCenter.subtract(bounds.center);
      var parts = getProductUnitMeshes(seedMesh);
      var starts = parts.map(function(m) { return m.position.clone(); });
      var dur = Math.max(80, durationMs || 500);
      var t0 = Date.now();
      if (seedMesh._dispenseObserver) {
        try { window.scene.onBeforeRenderObservable.remove(seedMesh._dispenseObserver); } catch (e) {}
        seedMesh._dispenseObserver = null;
      }
      seedMesh._dispenseObserver = window.scene.onBeforeRenderObservable.add(function() {
        var u = Math.min(1, (Date.now() - t0) / dur);
        var ease = easeIn ? (u * u) : (u * u * (3 - 2 * u));
        for (var i = 0; i < parts.length; i++) {
          parts[i].position.x = starts[i].x + delta.x * ease;
          parts[i].position.y = starts[i].y + delta.y * ease;
          parts[i].position.z = starts[i].z + delta.z * ease;
          forceShowOneProductMesh(parts[i]);
        }
        if (u >= 1) {
          try { window.scene.onBeforeRenderObservable.remove(seedMesh._dispenseObserver); } catch (e2) {}
          seedMesh._dispenseObserver = null;
          resolve(true);
        }
      });
    });
  }

  /** Landepunkt OBEN auf dem Korb, Spalte X behalten, vorne zur Kamera. */
  function basketLandingPoint(basket, keepX, forwardZ) {
    if (!basket) return null;
    basket.computeWorldMatrix(true);
    try { basket.refreshBoundingInfo(); } catch (e) {}
    var topY = elevatorBasketTopY(basket);
    var bb = basket.getBoundingInfo().boundingBox;
    try {
      var floor = null;
      var kids = basket.getChildMeshes ? basket.getChildMeshes(false) : [];
      for (var i = 0; i < kids.length; i++) {
        if (kids[i].name && /WideBasket_Floor/i.test(kids[i].name)) { floor = kids[i]; break; }
      }
      if (floor) {
        floor.computeWorldMatrix(true);
        bb = floor.getBoundingInfo().boundingBox;
      }
    } catch (e2) {}
    var zFront = forwardZ >= 0
      ? (bb.maximumWorld.z - 0.03)
      : (bb.minimumWorld.z + 0.03);
    return new BABYLON.Vector3(
      keepX,
      topY + 0.04,
      zFront
    );
  }

  window.stabilizeVendingShelf = function() {
    if (!window.scene) return JSON.stringify({ ok: false });
    var homes = captureAllShelfHomes(true);
    var products = resetAllShelfProductPoses();
    var spirals = resetAllSpiralHomes();
    return JSON.stringify({ ok: true, homes: homes, products: products, spirals: spirals });
  };

  window.collectDispensedProduct = function() {
    var mesh = window._dispensedProductMesh;
    if (!mesh) return JSON.stringify({ ok: false, error: 'none' });
    try {
      var parts = getProductUnitMeshes(mesh);
      for (var i = 0; i < parts.length; i++) {
        parts[i].isVisible = false;
        parts[i].setEnabled(false);
        parts[i].renderingGroupId = 0;
      }
    } catch (e) {}
    window._dispensedProductMesh = null;
    window._dispensedSlot = null;
    window._dispensedStack = null;
    return JSON.stringify({ ok: true });
  };

  /** stockBySlot: { "A1": 3 } → immer die vordersten N unsold Stacks (s00 zuerst). */
  window.syncVendingStock = function(stockBySlot) {
    if (!window.scene) return JSON.stringify({ ok: false });
    var map = stockBySlot || {};
    if (!window._saSoldStacks) window._saSoldStacks = {};
    if (!window._saLastStock) window._saLastStock = {};
    try { captureAllShelfHomes(false); } catch (eCap) {}
    // Bake-Pose zuerst, dann Home-Mitten sichern, dann Layout.
    try { resetAllShelfProductPoses(); } catch (ePose) {}
    try { captureSlotStackHomes(); } catch (eH) {}

    var slots = {};
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var mesh = window.scene.meshes[i];
      if (!mesh || !mesh.name) continue;
      var info = parseProductMeshName(mesh.name);
      if (!info) continue;
      if (!slots[info.slot]) slots[info.slot] = true;
    }
    // Auch Slots nur aus der Map (leere)
    for (var mk in map) {
      if (Object.prototype.hasOwnProperty.call(map, mk)) slots[mk] = true;
    }

    var touched = 0;
    for (var slot in slots) {
      if (!Object.prototype.hasOwnProperty.call(slots, slot)) continue;
      var stock = Object.prototype.hasOwnProperty.call(map, slot)
        ? Math.max(0, parseInt(map[slot], 10) || 0)
        : 0;
      var prev = window._saLastStock[slot];
      if (prev != null && stock > prev) {
        // Refill: verkaufte Stacks dieses Slots wieder freigeben
        clearSoldStacksForSlot(slot);
      }
      window._saLastStock[slot] = stock;
      touched += applySlotStockLayout(slot, stock);
    }
    return JSON.stringify({ ok: true, touched: touched });
  };

  function productStackKey(info) {
    if (!info) return '';
    return info.slot + '_s' + info.stack;
  }

  function isStackSold(info) {
    if (!info || !window._saSoldStacks) return false;
    return !!window._saSoldStacks[productStackKey(info)];
  }

  function markStackSold(info) {
    if (!info) return;
    if (!window._saSoldStacks) window._saSoldStacks = {};
    window._saSoldStacks[productStackKey(info)] = true;
  }

  function clearSoldStacksForSlot(slot) {
    if (!window._saSoldStacks || !slot) return;
    var prefix = slot + '_s';
    for (var k in window._saSoldStacks) {
      if (Object.prototype.hasOwnProperty.call(window._saSoldStacks, k) &&
          k.indexOf(prefix) === 0) {
        delete window._saSoldStacks[k];
      }
    }
  }

  /** Welt-Mitten der Bake-Posen je Stack (für Nachrücken nach vorne). */
  function captureSlotStackHomes() {
    if (!window.scene) return;
    if (!window._saSlotStackHomes) window._saSlotStackHomes = {};
    var seen = {};
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var mesh = window.scene.meshes[i];
      if (!mesh || !mesh.name) continue;
      var info = parseProductMeshName(mesh.name);
      if (!info) continue;
      var key = productStackKey(info);
      if (seen[key]) continue;
      seen[key] = true;
      // Dispense in der Bay nicht als Regal-Home speichern
      if (window._dispensedProductMesh &&
          getProductUnitMeshes(window._dispensedProductMesh).indexOf(mesh) >= 0) continue;
      ensureShelfMeshUnderRoot(mesh);
      mesh.computeWorldMatrix(true);
      var c = meshWorldCenter(mesh);
      if (!c) continue;
      if (!window._saSlotStackHomes[info.slot]) window._saSlotStackHomes[info.slot] = {};
      // Nur einmal sichern (Bake-Mitte)
      if (!window._saSlotStackHomes[info.slot][info.stack]) {
        window._saSlotStackHomes[info.slot][info.stack] = c.clone();
      }
    }
  }

  function getSlotFrontHomeCenter(slot, frontIndex) {
    var homes = window._saSlotStackHomes && window._saSlotStackHomes[slot];
    if (homes && homes[frontIndex]) return homes[frontIndex].clone();
    return null;
  }

  /** Ein Seed-Mesh pro Stack-Index (MultiMaterial-Teile zusammenfassen). */
  function listSlotStackUnits(slot) {
    var byStack = {};
    if (!window.scene) return [];
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var mesh = window.scene.meshes[i];
      if (!mesh || !mesh.name) continue;
      var info = parseProductMeshName(mesh.name);
      if (!info || info.slot !== slot) continue;
      if (byStack[info.stack] == null) {
        byStack[info.stack] = { mesh: mesh, info: info };
      }
    }
    var out = [];
    Object.keys(byStack).map(Number).sort(function(a, b) { return a - b; }).forEach(function(s) {
      out.push(byStack[s]);
    });
    return out;
  }

  /**
   * Sichtbarkeit + Nachrücken: immer die vordersten `stock` unsold Stacks.
   * s00 = Glas-Seite; verkauft = markiert und ausgeblendet.
   */
  function applySlotStockLayout(slot, stock) {
    var units = listSlotStackUnits(slot);
    var available = [];
    var touched = 0;
    var dispensedParts = window._dispensedProductMesh
      ? getProductUnitMeshes(window._dispensedProductMesh)
      : [];
    for (var u = 0; u < units.length; u++) {
      var unit = units[u];
      if (isStackSold(unit.info)) {
        var soldParts = getProductUnitMeshes(unit.mesh);
        for (var sp = 0; sp < soldParts.length; sp++) {
          if (dispensedParts.indexOf(soldParts[sp]) >= 0) continue;
          soldParts[sp].isVisible = false;
          soldParts[sp].setEnabled(false);
          touched++;
        }
        continue;
      }
      available.push(unit);
    }
    for (var ai = 0; ai < available.length; ai++) {
      var item = available[ai];
      var parts = getProductUnitMeshes(item.mesh);
      var isDispensing = false;
      for (var dp = 0; dp < parts.length; dp++) {
        if (dispensedParts.indexOf(parts[dp]) >= 0) { isDispensing = true; break; }
      }
      if (isDispensing) {
        for (var d0 = 0; d0 < parts.length; d0++) forceShowOneProductMesh(parts[d0]);
        touched += parts.length;
        continue;
      }
      var show = ai < stock;
      if (show) {
        // Bake-Pose zuerst (Höhe bleibt korrekt auf der Motor-Base).
        ensureShelfMeshUnderRoot(item.mesh);
        for (var p0 = 0; p0 < parts.length; p0++) ensureShelfMeshUnderRoot(parts[p0]);
        // Nur nachrücken wenn Stack nicht schon am Front-Index steht.
        // WICHTIG: nur horizontal/Tiefe — nie Y (Höhe), sonst sinken Dosen durch die Base.
        if (item.info.stack !== ai) {
          var targetC = getSlotFrontHomeCenter(slot, ai);
          if (targetC) {
            var bounds = productUnitWorldBounds(item.mesh);
            var curC = bounds ? bounds.center : meshWorldCenter(item.mesh);
            if (curC) {
              var delta = targetC.subtract(curC);
              delta.y = 0;
              if (delta.lengthSquared() > 1e-8) moveProductUnitBy(item.mesh, delta);
            }
          }
        }
        for (var p1 = 0; p1 < parts.length; p1++) {
          parts[p1].isVisible = true;
          parts[p1].setEnabled(true);
          parts[p1].visibility = 1.0;
          parts[p1].renderingGroupId = 0;
          touched++;
        }
      } else {
        for (var p2 = 0; p2 < parts.length; p2++) {
          ensureShelfMeshUnderRoot(parts[p2]);
          parts[p2].isVisible = false;
          parts[p2].setEnabled(false);
          touched++;
        }
      }
    }
    return touched;
  }

  function findSpiralMesh(row, col) {
    if (!window.scene) return null;
    // Exakt Motor_A1_Spiral — nie Motor_A10 bei col=1.
    var want = parseInt(col, 10);
    for (var i = 0; i < window.scene.meshes.length; i++) {
      var m = window.scene.meshes[i];
      if (!m || !m.name) continue;
      var mCol = m.name.match(new RegExp('^Motor_' + row + '0*(\\d+)_Spiral$', 'i'));
      if (!mCol) continue;
      if (parseInt(mCol[1], 10) === want) return m;
    }
    return null;
  }

  /** E/F: Schild 1–5 → physische Startspalte 1,3,5,7,9. */
  function resolveDoubleSlotPhysicalStart(row, col) {
    if (row !== 'E' && row !== 'F') return col;
    if (col >= 1 && col <= 5) return col * 2 - 1;
    if (col >= 2 && col <= 10 && (col % 2 === 0)) return col - 1;
    return col;
  }

  function findSpiralMeshesForSlot(row, col) {
    if (row === 'E' || row === 'F') {
      var start = resolveDoubleSlotPhysicalStart(row, col);
      var out = [];
      var a = findSpiralMesh(row, start);
      var b = findSpiralMesh(row, start + 1);
      if (a) out.push(a);
      if (b) out.push(b);
      return out;
    }
    var one = findSpiralMesh(row, col);
    return one ? [one] : [];
  }

  function findDeliveryAnchor() {
    return ensureElevatorBasket();
  }

  /** Welt-Oberkante der Ablagefläche (Floor), nicht der hohen Wand. */
  function elevatorBasketTopY(basket) {
    if (!basket) return 0;
    var floor = null;
    try {
      var kids = basket.getChildMeshes ? basket.getChildMeshes(false) : [];
      for (var i = 0; i < kids.length; i++) {
        if (kids[i].name && /WideBasket_Floor/i.test(kids[i].name)) { floor = kids[i]; break; }
      }
    } catch (e) {}
    if (!floor && basket.name && /WideBasket_Floor/i.test(basket.name)) floor = basket;
    if (!floor && window.scene) {
      for (var si = 0; si < window.scene.meshes.length; si++) {
        var sm = window.scene.meshes[si];
        if (sm && sm.name && /WideBasket_Floor/i.test(sm.name)) { floor = sm; break; }
      }
    }
    var target = floor || basket;
    target.computeWorldMatrix(true);
    try { target.refreshBoundingInfo(); } catch (e2) {}
    return target.getBoundingInfo().boundingBox.maximumWorld.y;
  }

  /** Ziel-Delta: Bodenfläche unter der Produkt-Unterkante (nicht in die Flasche hinein). */
  function elevatorDeltaForProduct(row, productMesh) {
    var basket = ensureElevatorBasket();
    var fallback = ELEVATOR_ROW_DELTA_Y[row] || 0.5;
    // A/B: genug Cap, damit die gleiche Clearance wie C–F nicht abgeschnitten wird.
    var drinkRow = (row === 'A' || row === 'B');
    var cap = (ELEVATOR_ROW_DELTA_Y[row] || 0.5) + (drinkRow ? 0.18 : 0.08);
    if (!basket) return fallback;
    captureElevatorHome();
    window.resetElevatorHome();
    var bTop = elevatorBasketTopY(basket);
    var bounds = productUnitWorldBounds(productMesh);
    var prodBottom = bounds ? bounds.min.y : null;
    if (prodBottom == null) {
      var prodC = meshWorldCenter(productMesh);
      if (!prodC) return fallback;
      prodBottom = prodC.y - 0.18;
    }
    // Gleicher Spalt wie bei C–F (nicht extra für Flaschen) — sonst bleibt bei A/B Luft.
    var clearance = 0.10;
    var delta = (prodBottom - clearance) - bTop;
    if (!(delta > 0.05)) delta = fallback * 0.85;
    return Math.min(cap, Math.max(0.12, delta));
  }

  function meshWorldCenter(mesh) {
    if (!mesh) return null;
    mesh.computeWorldMatrix(true);
    try {
      var bb = mesh.getBoundingInfo().boundingBox;
      return BABYLON.Vector3.Center(bb.minimumWorld, bb.maximumWorld);
    } catch (e) {
      return mesh.getAbsolutePosition ? mesh.getAbsolutePosition().clone() : mesh.position.clone();
    }
  }

  /**
   * GLB-Meshes sind gebacken (Verts schon am Regal, position oft 0).
   * Absolut-Weltziele als position setzen verschiebt das Produkt falsch (neben die Maschine).
   * Stattdessen: position-Delta, damit das Bounding-Center am Ziel landet.
   */
  function positionToPlaceCenterAt(mesh, targetWorld) {
    var center = meshWorldCenter(mesh);
    if (!center || !targetWorld) return mesh.position.clone();
    var delta = targetWorld.subtract(center);
    return mesh.position.add(delta);
  }

  function animateMeshTo(mesh, targetPos, durationMs, easeIn) {
    return new Promise(function(resolve) {
      if (!mesh || !window.scene) { resolve(false); return; }
      var dur = Math.max(80, durationMs || 500);
      var t0 = Date.now();
      var sx = mesh.position.x, sy = mesh.position.y, sz = mesh.position.z;
      var ex = targetPos.x, ey = targetPos.y, ez = targetPos.z;
      if (mesh._dispenseObserver) {
        try { window.scene.onBeforeRenderObservable.remove(mesh._dispenseObserver); } catch (e) {}
        mesh._dispenseObserver = null;
      }
      mesh._dispenseObserver = window.scene.onBeforeRenderObservable.add(function() {
        var u = Math.min(1, (Date.now() - t0) / dur);
        var ease = easeIn
          ? (u * u) // fall: beschleunigen
          : (u * u * (3 - 2 * u));
        mesh.position.x = sx + (ex - sx) * ease;
        mesh.position.y = sy + (ey - sy) * ease;
        mesh.position.z = sz + (ez - sz) * ease;
        if (u >= 1) {
          try { window.scene.onBeforeRenderObservable.remove(mesh._dispenseObserver); } catch (e2) {}
          mesh._dispenseObserver = null;
          resolve(true);
        }
      });
    });
  }

  function animateMeshDeltaY(mesh, deltaY, durationMs) {
    return new Promise(function(resolve) {
      if (!mesh || !window.scene) { resolve(false); return; }
      var end = mesh.position.clone();
      end.y += deltaY;
      animateMeshTo(mesh, end, durationMs).then(resolve);
    });
  }

  /**
   * Spirale auf der Stelle drehen (Coil-Achse = Längsachse).
   * Jeden Frame von Home aus mit Absolutwinkel — kein setPivot/setParent (sonst Orbit).
   */
  function animateSpiral(mesh, turns, durationMs) {
    return new Promise(function(resolve) {
      if (!mesh || !window.scene) { resolve(false); return; }
      captureMeshHome(mesh, false);
      restoreMeshHome(mesh);
      mesh.computeWorldMatrix(true);
      var home = mesh._saHome;
      var pivot = (home && home.center) ? home.center.clone() : meshWorldCenter(mesh);
      if (!pivot) { resolve(false); return; }
      var axis = (home && home.axis) ? home.axis.clone() : new BABYLON.Vector3(1, 0, 0);
      try { axis.normalize(); } catch (eN) {}
      if (typeof mesh.rotateAround !== 'function') {
        // Ohne rotateAround lieber nicht um Ursprung schleudern
        setTimeout(function() { resolve(false); }, Math.max(280, durationMs || 900));
        return;
      }
      var dur = Math.max(280, durationMs || 900);
      var t0 = Date.now();
      var total = (turns || 1.35) * Math.PI * 2;
      var obs = null;
      obs = window.scene.onBeforeRenderObservable.add(function() {
        var u = Math.min(1, (Date.now() - t0) / dur);
        var ease = u * u * (3 - 2 * u);
        var angle = total * ease;
        restoreMeshHome(mesh);
        try { mesh.rotateAround(pivot, axis, angle); } catch (eRot) {}
        if (u >= 1) {
          try { window.scene.onBeforeRenderObservable.remove(obs); } catch (e) {}
          // Nach Animation wieder exakt Home — Coil sieht gleich aus, Pose bleibt stabil
          restoreMeshHome(mesh);
          resolve(true);
        }
      });
    });
  }

  /**
   * Verfügbare Stacks eines Slots, vorderstes zuerst (niedrigster unsold Stack = Glas-Seite).
   */
  function listSlotStackMeshes(slot, stock) {
    var out = [];
    if (!window.scene) return out;
    var units = listSlotStackUnits(slot);
    var limit = (typeof stock === 'number' && stock >= 0) ? stock : 99;
    for (var i = 0; i < units.length; i++) {
      var unit = units[i];
      if (isStackSold(unit.info)) continue;
      if (out.length >= limit) break;
      out.push(unit);
    }
    return out;
  }

  /** Vorderstes verkaufbares Produkt der Reihe. */
  function pickFrontSlotMesh(slot, stock) {
    var list = listSlotStackMeshes(slot, Math.max(1, stock || 1));
    if (list.length) return list[0];
    var units = listSlotStackUnits(slot);
    for (var i = 0; i < units.length; i++) {
      if (!isStackSold(units[i].info)) return units[i];
    }
    return null;
  }

  /** Einheitlicher Schub nach vorne — alle Teile einer Einheit + alle Stack-Meshes. */
  function animateMeshesDeltaZ(meshes, deltaZ, durationMs) {
    return new Promise(function(resolve) {
      if (!window.scene || !meshes || !meshes.length) { resolve(false); return; }
      var all = [];
      for (var i = 0; i < meshes.length; i++) {
        var parts = getProductUnitMeshes(meshes[i]);
        for (var p = 0; p < parts.length; p++) {
          if (all.indexOf(parts[p]) < 0) all.push(parts[p]);
        }
      }
      var dur = Math.max(120, durationMs || 400);
      var t0 = Date.now();
      var starts = all.map(function(m) { return m.position.z; });
      var obs = window.scene.onBeforeRenderObservable.add(function() {
        var u = Math.min(1, (Date.now() - t0) / dur);
        var ease = u * u * (3 - 2 * u);
        for (var i = 0; i < all.length; i++) {
          all[i].position.z = starts[i] + deltaZ * ease;
          forceShowOneProductMesh(all[i]);
        }
        if (u >= 1) {
          try { window.scene.onBeforeRenderObservable.remove(obs); } catch (e) {}
          resolve(true);
        }
      });
    });
  }

  /** Nur das vordere Produkt fällt auf den Korb — X bleibt; Mitte = Boden + halbe Höhe. */
  function animateProductFallToBasket(mesh, basket, durationMs) {
    return new Promise(async function(resolve) {
      if (!mesh || !window.scene) { resolve(false); return; }
      var drink = isDrinkProductMesh(mesh);
      var dur = Math.max(drink ? 420 : 280, durationMs || 700);
      forceShowDispensingProduct(mesh);
      var bounds = productUnitWorldBounds(mesh);
      var curC = bounds ? bounds.center : meshWorldCenter(mesh);
      if (!curC) { resolve(false); return; }

      var forwardZ = -1;
      var flap = null;
      for (var fi = 0; fi < window.scene.meshes.length; fi++) {
        var fm = window.scene.meshes[fi];
        if (fm && fm.name && fm.name.indexOf('DeliveryFlap_Door') >= 0) { flap = fm; break; }
      }
      var flapC = flap ? meshWorldCenter(flap) : null;
      if (flapC && Math.abs(flapC.z - curC.z) > 1e-4) {
        forwardZ = (flapC.z - curC.z) > 0 ? 1 : -1;
      }

      var topY = basket ? elevatorBasketTopY(basket) : (curC.y - 0.35);
      var halfH = bounds ? Math.max(0.04, (bounds.max.y - bounds.min.y) * 0.5) : (drink ? 0.09 : 0.06);
      // Boden auf Korb — nicht Mittelpunkt in die Ablage drücken (Flaschen verschwinden sonst).
      var targetWorld = new BABYLON.Vector3(
        curC.x,
        topY + halfH + 0.02,
        curC.z + forwardZ * (drink ? 0.05 : 0.04)
      );
      var mid = new BABYLON.Vector3(
        curC.x,
        curC.y * 0.55 + targetWorld.y * 0.45,
        curC.z + forwardZ * 0.02
      );
      await animateProductUnitToCenter(mesh, mid, Math.floor(dur * 0.45), true);
      forceShowDispensingProduct(mesh);
      await animateProductUnitToCenter(mesh, targetWorld, Math.floor(dur * 0.55), true);
      forceShowDispensingProduct(mesh);
      resolve(true);
    });
  }

  /** Aufzug + Produkt (alle Teile) synchron nach unten. */
  function animateElevatorWithCargo(basket, cargo, deltaY, durationMs) {
    return new Promise(function(resolve) {
      if (!window.scene) { resolve(false); return; }
      ensureElevatorBasket();
      captureElevatorHome();
      var elevMeshes = listElevatorMeshes();
      if (!elevMeshes.length && basket) elevMeshes = [basket];
      var cargoParts = cargo ? getProductUnitMeshes(cargo) : [];
      var dur = Math.max(200, durationMs || 700);
      var t0 = Date.now();
      var elevStarts = elevMeshes.map(function(m) { return m.position.y; });
      var elevEnds = elevMeshes.map(function(m) {
        return (m._elevHomePos ? m._elevHomePos.y : m.position.y);
      });
      var cargoStarts = cargoParts.map(function(m) { return m.position.y; });
      if (window._elevatorAnimObs) {
        try { window.scene.onBeforeRenderObservable.remove(window._elevatorAnimObs); } catch (e) {}
        window._elevatorAnimObs = null;
      }
      window._elevatorAnimObs = window.scene.onBeforeRenderObservable.add(function() {
        var u = Math.min(1, (Date.now() - t0) / dur);
        var ease = u * u * (3 - 2 * u);
        for (var i = 0; i < elevMeshes.length; i++) {
          elevMeshes[i].position.y = elevStarts[i] + (elevEnds[i] - elevStarts[i]) * ease;
          showElevatorBasket(elevMeshes[i], true);
        }
        for (var c = 0; c < cargoParts.length; c++) {
          cargoParts[c].position.y = cargoStarts[c] - deltaY * ease;
          forceShowOneProductMesh(cargoParts[c]);
        }
        if (u >= 1) {
          try { window.scene.onBeforeRenderObservable.remove(window._elevatorAnimObs); } catch (e2) {}
          window._elevatorAnimObs = null;
          resolve(true);
        }
      });
    });
  }

  /** Nur der PUSH-Schriftzug blinkt N-mal (nicht die ganze Klappe). */
  function blinkPushFlap(times) {
    return new Promise(function(resolve) {
      if (!window.scene) { resolve(false); return; }

      var pushMats = [];
      var seen = {};
      function considerMat(mat) {
        if (!mat || !mat.name) return;
        var mn = String(mat.name);
        if (mn.indexOf('Push') < 0 && mn.toLowerCase().indexOf('push') < 0) return;
        // Nie Door/Edge-Kunststoff
        if (mn.indexOf('Door') >= 0 || mn.indexOf('Edge') >= 0) return;
        var key = mat.uniqueId != null ? String(mat.uniqueId) : mn;
        if (seen[key]) return;
        seen[key] = true;
        pushMats.push(mat);
      }
      function considerMesh(mesh) {
        if (!mesh || !mesh.material) return;
        if (mesh.material.subMaterials && mesh.material.subMaterials.length) {
          for (var i = 0; i < mesh.material.subMaterials.length; i++) {
            considerMat(mesh.material.subMaterials[i]);
          }
        } else {
          considerMat(mesh.material);
        }
      }

      for (var mi = 0; mi < window.scene.meshes.length; mi++) {
        var m = window.scene.meshes[mi];
        if (!m || !m.name) continue;
        var n = String(m.name);
        if (n.indexOf('DeliveryFlap_Door') >= 0 ||
            n.toLowerCase().indexOf('push') >= 0) {
          considerMesh(m);
        }
      }

      if (!pushMats.length) { resolve(false); return; }

      var saved = pushMats.map(function(mat) {
        return {
          mat: mat,
          em: mat.emissiveColor ? mat.emissiveColor.clone() : new BABYLON.Color3(0, 0, 0),
          ei: mat.emissiveIntensity != null ? mat.emissiveIntensity : 0
        };
      });
      var count = Math.max(1, times || 3);
      var step = 0;
      function setBright(on) {
        for (var i = 0; i < saved.length; i++) {
          var s = saved[i];
          if (!s || !s.mat) continue;
          if (on) {
            s.mat.emissiveColor = new BABYLON.Color3(1.0, 0.92, 0.35);
            if (s.mat.emissiveIntensity !== undefined) s.mat.emissiveIntensity = 3.2;
          } else {
            s.mat.emissiveColor = s.em;
            if (s.mat.emissiveIntensity !== undefined) s.mat.emissiveIntensity = s.ei;
          }
        }
      }
      function pulse() {
        if (step >= count) {
          setBright(false);
          resolve(true);
          return;
        }
        step++;
        setBright(true);
        setTimeout(function() {
          setBright(false);
          setTimeout(pulse, 140);
        }, 220);
      }
      pulse();
    });
  }

  /**
   * Ausgabe exakt:
   * 1) Aufzug zur Reihe
   * 2) Spirale dreht
   * 3) alle Produkte im Slot einheitlich nach vorne
   * 4) vorderstes fällt in den Aufzug
   * 5) Aufzug fährt runter
   * 6) PUSH blinkt 3×
   */
  window.dispenseVendingItem = function(slotCode, visibleStock, durationMs) {
    if (!window.scene) return JSON.stringify({ ok: false, error: 'no scene' });
    if (window._dispenseBusy) {
      return JSON.stringify({ ok: false, error: 'busy', durationMs: 200 });
    }
    var raw = String(slotCode || '').toUpperCase().replace(/^([A-F])0+(\d)/, '$1$2');
    var m = raw.match(/^([A-F])(\d{1,2})$/);
    if (!m) return JSON.stringify({ ok: false, error: 'bad slot' });
    var row = m[1];
    var col = parseInt(m[2], 10);
    // E/F: Tastatur/Schild F1–F5 → physische Produktspalte 1,3,5,7,9
    var meshCol = (row === 'E' || row === 'F')
      ? resolveDoubleSlotPhysicalStart(row, col)
      : col;
    var slot = row + String(meshCol);
    var stock = Math.max(0, parseInt(visibleStock, 10) || 0);
    // Längere Sequenz für sichtbare Schritte
    var totalDur = (typeof durationMs === 'number' && durationMs > 0) ? durationMs : 5600;

    try { captureSlotStackHomes(); } catch (eH0) {}
    try { applySlotStockLayout(slot, stock); } catch (eLay) {}

    // IMMER das vorderste verfügbare Produkt (s00 / niedrigster unsold Stack)
    var front = pickFrontSlotMesh(slot, stock);
    var mesh = front ? front.mesh : null;
    var meshInfo = front ? front.info : null;
    var targetStack = meshInfo ? meshInfo.stack : 0;
    var stackList = listSlotStackMeshes(slot, Math.max(stock, 1));

    if (!mesh) return JSON.stringify({ ok: false, error: 'mesh not found', slot: slot, durationMs: 120 });

    // Vorherigen Versatz bereinigen, Layout halten (vorderstes bleibt vorne)
    try {
      captureAllShelfHomes(false);
      resetAllSpiralHomes();
      applySlotStockLayout(slot, stock);
      // Pick erneut nach Layout (gleiche Front)
      front = pickFrontSlotMesh(slot, stock);
      if (front) {
        mesh = front.mesh;
        meshInfo = front.info;
        targetStack = meshInfo.stack;
      }
      stackList = listSlotStackMeshes(slot, Math.max(stock, 1));
    } catch (eClean) {}

    window._dispenseBusy = true;
    window._dispenseDone = false;
    window._dispensedProductMesh = mesh;
    window._dispensedSlot = slot;
    window._dispensedStack = meshInfo ? meshInfo.stack : targetStack;
    forceShowDispensingProduct(mesh);
    // KEIN setParent auf Bake-Meshes — zerstört die Pose (Riesen-Versatz).

    var basket = ensureElevatorBasket();
    captureElevatorHome();
    window.resetElevatorHome();

    var deltaY = elevatorDeltaForProduct(row, mesh);
    var tElevUp = Math.floor(totalDur * 0.22);
    var tSpiral = Math.floor(totalDur * 0.20);
    var tPush = Math.floor(totalDur * 0.14);
    var tFall = Math.floor(totalDur * 0.18);
    var tElevDown = Math.floor(totalDur * 0.18);
    var tBlink = Math.max(900, totalDur - tElevUp - tSpiral - tPush - tFall - tElevDown);
    var meshName = mesh.name;
    var spirals = findSpiralMeshesForSlot(row, col);

    // Vorwärtsschub-Richtung einmal bestimmen
    var startC0 = meshWorldCenter(mesh);
    var forwardZ = -1;
    for (var fi = 0; fi < window.scene.meshes.length; fi++) {
      var fm = window.scene.meshes[fi];
      if (fm && fm.name && fm.name.indexOf('DeliveryFlap_Door') >= 0) {
        var fc = meshWorldCenter(fm);
        if (fc && startC0 && Math.abs(fc.z - startC0.z) > 1e-4) {
          forwardZ = (fc.z - startC0.z) > 0 ? 1 : -1;
        }
        break;
      }
    }
    // Nur leichter Vorschub — 0.26 schiebt Produkte durchs Glas nach draußen.
    var pushDist = 0.06;

    (async function() {
      try {
        // 1) Aufzug zur Reihe — Produkte warten
        await animateElevatorDeltaY(deltaY, tElevUp);
        basket = ensureElevatorBasket();
        forceShowDispensingProduct(mesh);

        // 2) Spirale(n) drehen — E/F: beide Motoren; rechte Spirale gegenläufig
        if (spirals.length) {
          await Promise.all(spirals.map(function(sp) {
            var turns = 1.5;
            try {
              var mCol = String(sp.name || '').match(/Motor_[A-F]0*(\d+)_Spiral/i);
              if (mCol && (parseInt(mCol[1], 10) % 2 === 0)) turns = -1.5;
            } catch (eDir) {}
            return animateSpiral(sp, turns, tSpiral);
          }));
        } else {
          await new Promise(function(r) { setTimeout(r, Math.min(200, tSpiral)); });
        }

        // 3) Alle Produkte im Slot leicht nach vorne (bleiben im Slot)
        var peers = listSlotStackMeshes(slot, stock);
        if (!peers.length) peers = [{ mesh: mesh, info: meshInfo }];
        var peerMeshes = peers.map(function(p) { return p.mesh; });
        for (var p = 0; p < peerMeshes.length; p++) {
          forceShowDispensingProduct(peerMeshes[p]);
        }
        await animateMeshesDeltaZ(peerMeshes, forwardZ * pushDist, tPush);

        // 4a) AntiTheft einfahren — Durchlass für den Fall
        await setAntiTheftRetractedAsync(true, Math.min(320, Math.floor(tFall * 0.35)));

        // 4) Vorderstes fällt in den Aufzug (nur Y + Mini-Z)
        forceShowDispensingProduct(mesh);
        await animateProductFallToBasket(mesh, basket, tFall);
        window._dispensedProductMesh = mesh;
        // Verkauf markieren — bleibt ausgeblendet; Rest rückt beim nächsten Sync nach
        try { markStackSold(meshInfo); } catch (eSold) {}

        // Rest der Reihe: Schub rückgängig + auf Front-Positionen verdichten (stock-1)
        for (var r = 0; r < peerMeshes.length; r++) {
          if (peerMeshes[r] === mesh) continue;
          var rParts = getProductUnitMeshes(peerMeshes[r]);
          var skip = false;
          for (var rp = 0; rp < rParts.length; rp++) {
            if (window._dispensedProductMesh &&
                getProductUnitMeshes(window._dispensedProductMesh).indexOf(rParts[rp]) >= 0) {
              skip = true; break;
            }
          }
          if (!skip) resetProductBakePose(peerMeshes[r]);
        }
        try { applySlotStockLayout(slot, Math.max(0, stock - 1)); } catch (eComp) {}
        forceShowDispensingProduct(mesh);

        // 5) Aufzug + Produkt runter
        await animateElevatorWithCargo(basket, mesh, deltaY, tElevDown);
        forceShowDispensingProduct(mesh);
        window.resetElevatorHome();
        forceShowDispensingProduct(mesh);

        // 5b) AntiTheft wieder verschließen
        await setAntiTheftRetractedAsync(false, 320);

        // 6) PUSH blinkt 3×
        await blinkPushFlap(3);
        if (tBlink > 1100) {
          await new Promise(function(r) { setTimeout(r, Math.min(400, tBlink - 900)); });
        }
      } catch (err) {
        forceShowDispensingProduct(mesh);
        window.resetElevatorHome();
        try { window.resetAntiTheftHome(); } catch (eAt) {}
        try { resetAllShelfProductPoses(); } catch (eR) {}
        try { resetAllSpiralHomes(); } catch (eS) {}
      } finally {
        window._dispenseBusy = false;
        window._dispenseDone = true;
        try { if (meshInfo) markStackSold(meshInfo); } catch (eSold2) {}
        try { resetAllSpiralHomes(); } catch (eS2) {}
        try { window.resetAntiTheftHome(); } catch (eAt2) {}
      }
    })();

    return JSON.stringify({
      ok: true,
      slot: slot,
      input: raw,
      mesh: meshName,
      frontStack: targetStack,
      spirals: spirals.map(function(s) { return s.name; }),
      spiral: spirals.length ? spirals[0].name : null,
      elevator: basket ? basket.name : null,
      deltaY: deltaY,
      peers: stackList.length,
      durationMs: totalDur
    });
  };

  window.ensureVendingPresentation = function() {
    if (!window.scene) return JSON.stringify({ ok: false });
    var scene = window.scene;
    try {
      // Neutraler Studio-Hintergrund (Styles überschreiben clearColor).
      scene.clearColor = new BABYLON.Color4(0.28, 0.30, 0.33, 1.0);
      scene.ambientColor = new BABYLON.Color3(0.35, 0.37, 0.40);
      if (scene.imageProcessingConfiguration) {
        scene.imageProcessingConfiguration.contrast = 1.06;
        scene.imageProcessingConfiguration.exposure = 0.92;
        scene.imageProcessingConfiguration.toneMappingEnabled = true;
      }
      if (!scene._vendingEnvReady) {
        try {
          if (typeof scene.createDefaultEnvironment === 'function' && !scene._vendingEnvHelper) {
            scene._vendingEnvHelper = scene.createDefaultEnvironment({
              createGround: false,
              createSkybox: true,
              skyboxSize: 100,
              skyboxColor: new BABYLON.Color3(0.72, 0.75, 0.80),
              enableGroundShadow: false,
              cameraContrast: 1.05,
              cameraExposure: 1.2
            });
            if (scene._vendingEnvHelper && scene._vendingEnvHelper.skybox) {
              scene._vendingEnvHelper.skybox.isPickable = false;
            }
          }
          scene.environmentIntensity = Math.max(scene.environmentIntensity || 0, 0.85);
          scene._vendingEnvReady = true;
        } catch (e) {
          scene._vendingEnvReady = true;
        }
      }
      if (!scene._vendingExtraLights) {
        var hemi = new BABYLON.HemisphericLight('VendingHemiFill', new BABYLON.Vector3(0.15, 1.0, 0.25), scene);
        hemi.intensity = 0.55;
        hemi.diffuse = new BABYLON.Color3(0.95, 0.96, 0.98);
        hemi.groundColor = new BABYLON.Color3(0.28, 0.30, 0.32);
        var key = new BABYLON.DirectionalLight('VendingKey', new BABYLON.Vector3(-0.45, -0.65, -0.55), scene);
        key.intensity = 0.7;
        key.diffuse = new BABYLON.Color3(1.0, 0.98, 0.94);
        var fill = new BABYLON.DirectionalLight('VendingFill', new BABYLON.Vector3(0.65, -0.1, 0.35), scene);
        fill.intensity = 0.35;
        fill.diffuse = new BABYLON.Color3(0.7, 0.8, 1.0);
        var front = new BABYLON.DirectionalLight('VendingFront', new BABYLON.Vector3(0.05, -0.05, -1.0), scene);
        front.intensity = 0.55;
        front.diffuse = new BABYLON.Color3(1.0, 1.0, 1.0);
        var rim = new BABYLON.DirectionalLight('VendingRim', new BABYLON.Vector3(0.15, 0.35, 0.95), scene);
        rim.intensity = 0.3;
        rim.diffuse = new BABYLON.Color3(0.65, 0.75, 1.0);
        scene._vendingExtraLights = [hemi, key, fill, front, rim];
        // Basis-Intensitäten, genutzt von applyVendingMaterialStyle lightMul.
        scene._vendingExtraLightBase = {
          VendingHemiFill: 1.15, VendingKey: 1.35, VendingFill: 0.7,
          VendingFront: 1.1, VendingRim: 0.65
        };
      }
      for (var i = 0; i < scene.meshes.length; i++) {
        var mesh = scene.meshes[i];
        if (!mesh || !mesh.getBoundingInfo) continue;
        try {
          var c = mesh.getBoundingInfo().boundingBox.centerWorld;
          if (Math.abs(c.x) > 5 || Math.abs(c.y) > 5 || Math.abs(c.z) > 5) {
            mesh.setEnabled(false);
            mesh.isVisible = false;
          }
        } catch (e) {}
      }
      // Debug-Zonen/LEDs aus; nur moderner GLB-Korb (Floor/Wall) sichtbar.
      for (var zi = 0; zi < scene.meshes.length; zi++) {
        var zm = scene.meshes[zi];
        if (!zm || !zm.name) continue;
        var zn = zm.name;
        if (/WideBasket_Runtime/i.test(zn)) {
          try { zm.dispose(); } catch (eRt) {}
          continue;
        }
        if (zn.indexOf('Zone') >= 0 || zn.indexOf('SA_Zone') >= 0 ||
            zn.indexOf('Parking_Zone') >= 0 ||
            zn.indexOf('InteriorLED') >= 0) {
          zm.setEnabled(false);
          zm.isVisible = false;
          zm.visibility = 0;
          continue;
        }
        // Schienen/Gurte/Pulleys: unsichtbar lassen (Gehäuse), Korb zeigen.
        if (zn.indexOf('Elevator_') >= 0 || /WideBasket/i.test(zn)) {
          if (/WideBasket/i.test(zn) && !/WideBasket_Runtime/i.test(zn)) {
            zm.setEnabled(true);
            zm.isVisible = true;
            zm.visibility = 1;
          } else if (/Rail|Pulley|Belt|Cable|Guide|Frame|Housing|Track|SideLED|Light|Root|InteriorFill/i.test(zn)) {
            zm.setEnabled(false);
            zm.isVisible = false;
            zm.visibility = 0;
          }
        }
      }
      // Moderner GLB-Korb verdrahten (kein CreateBox-Fallback).
      try { if (typeof ensureElevatorBasket === 'function') ensureElevatorBasket(); } catch (eB) {}
      // Klappe zurücksetzen — kaputte Hinge-Rotation = graue Platte auf Regalhöhe.
      try { if (typeof window.resetDeliveryFlapHome === 'function') window.resetDeliveryFlapHome(); } catch (eFlap) {}
      // AntiTheft: geschlossen + sichtbar (GLB-Pose frame 1).
      try { if (typeof window.resetAntiTheftHome === 'function') window.resetAntiTheftHome(); } catch (eAt) {}
      try { if (typeof ensureAntiTheftVisible === 'function') ensureAntiTheftVisible(); } catch (eAt2) {}
      try {
        var flapDoor = null;
        for (var fdi = 0; fdi < scene.meshes.length; fdi++) {
          var fdm = scene.meshes[fdi];
          if (fdm && fdm.name && fdm.name.indexOf('DeliveryFlap_Door') >= 0) {
            flapDoor = fdm; break;
          }
        }
        if (flapDoor && typeof attachPushMeshesToDoor === 'function') {
          attachPushMeshesToDoor(flapDoor);
        }
      } catch (ePush) {}
      // Aufzug immer in Park-/Home-Pose nach Laden.
      try { if (typeof window.resetElevatorHome === 'function') window.resetElevatorHome(); } catch (eElev) {}
      // Zuerst Homes der Regal-Meshes sichern (unter __root__), dann zurücksetzen.
      try { captureAllShelfHomes(false); } catch (eCap) {}
      try { resetAllProductGlow(); } catch (eGlow) {}
      try { resetAllShelfProductPoses(); } catch (ePose) {}
      try { resetAllSpiralHomes(); } catch (eSp) {}
      if (scene.imageProcessingConfiguration) {
        scene.imageProcessingConfiguration.exposure = Math.min(
          scene.imageProcessingConfiguration.exposure || 1.0, 0.95
        );
      }
      // Hard-Surface Flat Shading — entfernt N-Gon-Dellen-Artefakte an Panels/Gehäuse.
      for (var fi = 0; fi < scene.meshes.length; fi++) {
        var fm = scene.meshes[fi];
        if (!fm || !fm.name) continue;
        var fn = fm.name;
        var wantFlat =
          fn.indexOf('ControlPanel') >= 0 || fn.indexOf('RightPanel') >= 0 ||
          fn.indexOf('LeftBody') >= 0 || fn.indexOf('Vending_Roof') >= 0 ||
          fn.indexOf('CornerCap') >= 0 ||
          // Delivery-Bay/Frame ja — Door mit PUSH-Lettering NIEMALS flat-shaden
          // (sonst reißt Mat_Flap_Push als schwebendes Mesh ab).
          (fn.indexOf('Delivery') >= 0 && fn.indexOf('DeliveryFlap_Door') < 0) ||
          fn.indexOf('LowerRear') >= 0 || fn.indexOf('AntiTheft') >= 0 ||
          fn.indexOf('CoinMod_') >= 0 || fn.indexOf('CoinReturn_') >= 0 ||
          fn.indexOf('KP_Plate') >= 0 || fn.indexOf('EPort_Body') >= 0 ||
          fn.indexOf('EPort_ScreenFrame') >= 0 || fn.indexOf('HUD_Frame') >= 0 ||
          fn.indexOf('Vending_Foot') >= 0 ||
          (fn.indexOf('_Plate') >= 0);
        if (wantFlat) {
          try {
            if (!fm._saFlatForced && fm.convertToFlatShadedMesh) {
              fm.convertToFlatShadedMesh();
              fm._saFlatForced = true;
            }
          } catch (e) {}
          var fmats = fm.material ? (fm.material.subMaterials || [fm.material]) : [];
          for (var fmi = 0; fmi < fmats.length; fmi++) {
            var fmat = fmats[fmi];
            if (!fmat) continue;
            if (fmat.roughness !== undefined) fmat.roughness = Math.max(fmat.roughness || 0, 0.48);
            if (fmat.metallic !== undefined) fmat.metallic = Math.min(fmat.metallic || 0, 0.72);
            if (fmat.environmentIntensity !== undefined) {
              fmat.environmentIntensity = Math.min(fmat.environmentIntensity || 1, 0.45);
            }
            if (fmat.specularIntensity !== undefined) fmat.specularIntensity = 0.28;
          }
        }
        // HUD-/EPort-Bildschirme: solides Fast-Schwarz, außer OLED-Textur auf HUD aktiv.
        if ((fn.indexOf('HUD_Screen') >= 0 && !scene._vendingHudOled) ||
            (fn.indexOf('EPort_Screen') >= 0 && fn.indexOf('Frame') < 0) ||
            fn.indexOf('ScreenPlaceholder') >= 0) {
          try {
            var smat = new BABYLON.PBRMaterial('VendingScreenForce_' + fi, scene);
            smat.albedoColor = new BABYLON.Color3(0.02, 0.02, 0.025);
            smat.metallic = 0.0;
            smat.roughness = 0.95;
            smat.environmentIntensity = 0.0;
            smat.alpha = 1.0;
            smat.transparencyMode = BABYLON.Material.MATERIAL_OPAQUE;
            smat.backFaceCulling = false;
            fm.material = smat;
            fm.setEnabled(true);
            fm.isVisible = true;
            fm.visibility = 1.0;
            fm.renderingGroupId = 0;
          } catch (e) {}
        }
        if (fn.indexOf('HUD_Frame') >= 0 || fn.indexOf('HUD_Screen') >= 0 ||
            fn.indexOf('HUD_Glass') >= 0 || fn.indexOf('EPort_') >= 0 ||
            fn.indexOf('KP_') >= 0 || fn.indexOf('CoinMod_') >= 0 ||
            fn.indexOf('CoinReturn_') >= 0) {
          fm.setEnabled(true);
          fm.isVisible = true;
          fm.visibility = 1.0;
          // Kontaktlos / Labels lesbar halten
          if (fn.indexOf('Contactless') >= 0 || fn.indexOf('Label_') >= 0 ||
              fn.indexOf('LED_') >= 0) {
            fm.renderingGroupId = 0;
            try { fm.alwaysSelectAsActiveMesh = true; } catch (e) {}
          }
        }
      }
      for (var i = 0; i < scene.meshes.length; i++) {
        var mesh = scene.meshes[i];
        if (!mesh || !mesh.name) continue;
        var nm = mesh.name;
        var mats = mesh.material ? (mesh.material.subMaterials || [mesh.material]) : [];
        // Glas: kein Innen-Spiegel-Ghosting
        if (nm.indexOf('Glass') >= 0) {
          mesh.visibility = 0.55;
          for (var g = 0; g < mats.length; g++) {
            var gm = mats[g];
            if (!gm) continue;
            gm.transparencyMode = BABYLON.Material.MATERIAL_ALPHABLEND;
            if (gm.alpha !== undefined) gm.alpha = 0.08;
            if (gm.albedoColor) gm.albedoColor = new BABYLON.Color3(0.82, 0.9, 0.95);
            if (gm.metallic !== undefined) gm.metallic = 0.0;
            if (gm.roughness !== undefined) gm.roughness = 0.22;
            if (gm.reflectivityColor) gm.reflectivityColor = new BABYLON.Color3(0.04, 0.04, 0.05);
            if (gm.reflectionColor) gm.reflectionColor = new BABYLON.Color3(0.02, 0.02, 0.03);
            if (gm.environmentIntensity !== undefined) gm.environmentIntensity = 0.05;
            if (gm.indexOfRefraction !== undefined) gm.indexOfRefraction = 1.0;
            try { gm.reflectionTexture = null; } catch (e) {}
          }
          continue;
        }
        // Gehäuse / Panels: gebürstetes Metall-Highlight
        var isShell =
          nm.indexOf('LeftBody') >= 0 ||
          nm.indexOf('RightPanel') >= 0 ||
          nm.indexOf('Vending_Roof') >= 0 ||
          nm.indexOf('Vending_Foot') >= 0 ||
          nm.indexOf('ControlPanel') >= 0 ||
          nm.indexOf('Delivery') >= 0 ||
          nm.indexOf('LowerFront') >= 0 ||
          nm.indexOf('CornerCap') >= 0 ||
          nm.indexOf('Cabinet') >= 0;
        var isFlap = nm.indexOf('AntiTheft') >= 0 || nm.indexOf('antitheft') >= 0;
        for (var j = 0; j < mats.length; j++) {
          var mat = mats[j];
          if (!mat) continue;
          // HASHED/BLEND-Imports wirken geisterhaft — solides Depth-Write erzwingen.
          if (isFlap || isShell) {
            mat.alpha = 1.0;
            mat.transparencyMode = BABYLON.Material.MATERIAL_OPAQUE;
            mat.backFaceCulling = false;
            if (mat.forceDepthWrite !== undefined) mat.forceDepthWrite = true;
            if (mat.needDepthPrePass !== undefined) mat.needDepthPrePass = true;
            try { mat.transparencyMode = BABYLON.PBRMaterial.PBRMATERIAL_OPAQUE; } catch (e) {}
            mesh.renderingGroupId = 0;
            mesh.visibility = 1.0;
          }
          if (isFlap) {
            if (mat.albedoColor) mat.albedoColor = new BABYLON.Color3(0.28, 0.29, 0.31);
            if (mat.metallic !== undefined) mat.metallic = 0.6;
            if (mat.roughness !== undefined) mat.roughness = 0.34;
            if (mat.environmentIntensity !== undefined) mat.environmentIntensity = 1.2;
            continue;
          }
          if (isShell) {
            if (mat.albedoColor) {
              mat.albedoColor = new BABYLON.Color3(
                Math.max(mat.albedoColor.r, 0.58),
                Math.max(mat.albedoColor.g, 0.60),
                Math.max(mat.albedoColor.b, 0.64)
              );
            }
            if (mat.metallic !== undefined) mat.metallic = 0.68;
            if (mat.roughness !== undefined) mat.roughness = 0.30;
            if (mat.environmentIntensity !== undefined) mat.environmentIntensity = 1.4;
          }
        }
      }
      return JSON.stringify({ ok: true, lights: (scene._vendingExtraLights || []).length, metalGlassFix: true });
    } catch (err) {
      return JSON.stringify({ ok: false, error: String(err) });
    }
  };

  // Shell-/Glas-Materialien zwangsweise ersetzen — importiertes PBR bleibt oft schwarz in der WebView.
  window.applyVendingMaterialStyle = function(styleId) {
    if (!window.scene) return JSON.stringify({ ok: false });
    var scene = window.scene;
    var style = styleId || 'studio_metal';
    var presets = {
      blender: {
        // GLB-Materialien 1:1 aus Blender; nur Backdrop + Glas bereinigen.
        shellAlbedo: [0.72, 0.74, 0.78], shellMetal: 0.78, shellRough: 0.26,
        flapAlbedo: [0.35, 0.36, 0.38], flapMetal: 0.65, flapRough: 0.32,
        glassAlpha: 0.02, glassAlbedo: [1.0, 1.0, 1.0],
        env: 0.95, clear: [0.42, 0.44, 0.48], preserveAll: true,
        lightMul: 0.55, exposure: 0.92
      },
      blender_dark: {
        // Dieselben GLB-Materialien, dunklerer Studio-Look (weniger Auswaschen).
        shellAlbedo: [0.55, 0.56, 0.58], shellMetal: 0.72, shellRough: 0.32,
        flapAlbedo: [0.28, 0.29, 0.31], flapMetal: 0.6, flapRough: 0.36,
        glassAlpha: 0.03, glassAlbedo: [0.85, 0.9, 0.95],
        env: 0.55, clear: [0.22, 0.23, 0.26], preserveAll: true,
        lightMul: 0.32, exposure: 0.78
      },
      studio_metal: {
        shellAlbedo: [0.72, 0.74, 0.78], shellMetal: 0.78, shellRough: 0.26,
        flapAlbedo: [0.35, 0.36, 0.38], flapMetal: 0.65, flapRough: 0.32,
        glassAlpha: 0.14, glassAlbedo: [0.78, 0.88, 0.94],
        env: 1.2, clear: [0.45, 0.47, 0.52], lightMul: 0.7, exposure: 1.0
      },
      enamel: {
        shellAlbedo: [0.18, 0.19, 0.21], shellMetal: 0.22, shellRough: 0.38,
        flapAlbedo: [0.14, 0.14, 0.15], flapMetal: 0.25, flapRough: 0.4,
        glassAlpha: 0.16, glassAlbedo: [0.8, 0.88, 0.94],
        env: 0.9, clear: [0.32, 0.34, 0.38], lightMul: 0.55, exposure: 0.9
      },
      matte: {
        shellAlbedo: [0.42, 0.43, 0.45], shellMetal: 0.05, shellRough: 0.62,
        flapAlbedo: [0.3, 0.3, 0.32], flapMetal: 0.05, flapRough: 0.55,
        glassAlpha: 0.12, glassAlbedo: [0.88, 0.92, 0.95],
        env: 0.7, clear: [0.48, 0.50, 0.54], lightMul: 0.6, exposure: 0.95
      }
    };
    var p = presets[style] || presets.studio_metal;
    scene.clearColor = new BABYLON.Color4(p.clear[0], p.clear[1], p.clear[2], 1.0);
    scene.environmentIntensity = p.env;
    // Studio-Fill-Lights von ensureVendingPresentation dimmen/verstärken.
    try {
      var mul = (p.lightMul != null) ? p.lightMul : 1.0;
      var base = {
        VendingHemiFill: 1.15, VendingKey: 1.35, VendingFill: 0.7,
        VendingFront: 1.1, VendingRim: 0.65
      };
      if (scene._vendingExtraLights) {
        for (var li = 0; li < scene._vendingExtraLights.length; li++) {
          var L = scene._vendingExtraLights[li];
          if (!L || !L.name) continue;
          if (base[L.name] != null) L.intensity = base[L.name] * mul;
        }
      }
      if (scene.imageProcessingConfiguration && p.exposure != null) {
        scene.imageProcessingConfiguration.exposure = p.exposure;
      }
    } catch (e) {}
    // Depth-Buffer ueber Gruppen hinweg, damit opakes Gehaeuse Glas-Geister verdeckt.
    try {
      scene.setRenderingAutoClearDepthStencil(0, true, true, true);
      scene.setRenderingAutoClearDepthStencil(1, false, false, false);
    } catch (e) {}
    var touched = 0;
    function isShellName(nm) {
      nm = (nm || '').toLowerCase();
      // DeliveryFlap-Tür behält Multi-Material-PUSH-Lettering — nie als Gehäuse behandeln.
      if (nm.indexOf('deliveryflap_door') >= 0 || nm.indexOf('deliveryflap_push') >= 0) {
        return false;
      }
      return nm.indexOf('leftbody') >= 0 || nm.indexOf('rightpanel') >= 0 ||
        nm.indexOf('vending_roof') >= 0 || nm.indexOf('vending_foot') >= 0 ||
        nm.indexOf('controlpanel') >= 0 || nm.indexOf('deliverybay') >= 0 ||
        nm.indexOf('deliveryflap_frame') >= 0 ||
        nm.indexOf('lowerfront') >= 0 || nm.indexOf('lowerrear') >= 0 ||
        nm.indexOf('cornercap') >= 0 || nm.indexOf('apron') >= 0 ||
        nm.indexOf('interiorback') >= 0 || nm.indexOf('backplate') >= 0 ||
        nm.indexOf('slotliner') >= 0 ||
        (nm.indexOf('vending_') >= 0 && nm.indexOf('glass') < 0 &&
         nm.indexOf('product') < 0 && nm.indexOf('motor') < 0 &&
         nm.indexOf('divider') < 0 && nm.indexOf('elevator') < 0 &&
         nm.indexOf('label') < 0 && nm.indexOf('deliveryflap_door') < 0);
    }
    function isDeliveryFlapDoorName(nm) {
      nm = (nm || '').toLowerCase();
      return nm.indexOf('deliveryflap_door') >= 0;
    }
    function isGlassName(nm) {
      nm = (nm || '').toLowerCase();
      return nm.indexOf('glass') >= 0;
    }
    function isFlapName(nm) {
      nm = (nm || '').toLowerCase();
      return nm.indexOf('antitheft') >= 0;
    }
    function hasAlbedoTex(mesh) {
      var mat = mesh.material;
      if (!mat) return false;
      var mats = mat.subMaterials || [mat];
      for (var ti = 0; ti < mats.length; ti++) {
        var tm = mats[ti];
        if (!tm) continue;
        if (tm.albedoTexture || tm.bumpTexture || tm.metallicTexture ||
            tm.metallicRoughnessTexture || tm.reflectivityTexture) return true;
      }
      return false;
    }
    function makeOpaque(mat) {
      mat.alpha = 1.0;
      mat.transparencyMode = BABYLON.Material.MATERIAL_OPAQUE;
      mat.backFaceCulling = false;
      mat.separateCullingPass = false;
      if (mat.needDepthPrePass !== undefined) mat.needDepthPrePass = true;
      if (mat.forceDepthWrite !== undefined) mat.forceDepthWrite = true;
      try { mat.transparencyMode = BABYLON.PBRMaterial.PBRMATERIAL_OPAQUE; } catch (e) {}
    }
    // Blender 1:1 — exportierte Materialien behalten, nur Glas + Opacity bereinigen.
    if (p.preserveAll) {
      for (var bi = 0; bi < scene.meshes.length; bi++) {
        var bmesh = scene.meshes[bi];
        if (!bmesh || !bmesh.name || !bmesh.getTotalVertices || bmesh.getTotalVertices() < 3) continue;
        try {
          var bnm = bmesh.name;
          // Nur Haupt-Schaufensterglas — UI_HUD_Glass NICHT als Gehäuse-Glas behandeln
          // (dadurch verschwand das HUD / wirkte leer).
          var isMainGlass = bnm.indexOf('GlassPane') >= 0 ||
            (bnm.indexOf('Glass') >= 0 && bnm.indexOf('HUD') < 0 && bnm.indexOf('EPort') < 0);
          if (isMainGlass) {
            var bg = new BABYLON.PBRMaterial('VendingGlass_blender_' + bi, scene);
            bg.albedoColor = new BABYLON.Color3(1, 1, 1);
            bg.alpha = 0.02;
            bg.metallic = 0.0;
            bg.roughness = 1.0;
            bg.environmentIntensity = 0.0;
            bg.reflectivityColor = new BABYLON.Color3(0, 0, 0);
            bg.transparencyMode = BABYLON.Material.MATERIAL_ALPHABLEND;
            bg.backFaceCulling = true;
            bg.disableDepthWrite = true;
            bmesh.material = bg;
            bmesh.renderingGroupId = 1;
            touched++;
            continue;
          }
          if (bnm.indexOf('HUD_Glass') >= 0) {
            // Fast unsichtbare Abdeckung über schwarzem Bildschirm
            bmesh.visibility = 0.05;
            bmesh.renderingGroupId = 1;
            touched++;
            continue;
          }
          if (bnm.indexOf('HUD_Screen') >= 0 && scene._vendingHudOled) {
            bmesh.setEnabled(true);
            bmesh.isVisible = true;
            bmesh.visibility = 1.0;
            bmesh.renderingGroupId = 0;
            touched++;
            continue;
          }
          if (bnm.indexOf('HUD_Screen') >= 0 || (bnm.indexOf('EPort_Screen') >= 0 && bnm.indexOf('Frame') < 0)) {
            var bscreen = new BABYLON.PBRMaterial('VendingHUDScreen_' + bi, scene);
            bscreen.albedoColor = new BABYLON.Color3(0.015, 0.015, 0.02);
            bscreen.metallic = 0.0;
            bscreen.roughness = 0.95;
            bscreen.environmentIntensity = 0.0;
            bscreen.alpha = 1.0;
            makeOpaque(bscreen);
            bmesh.material = bscreen;
            bmesh.setEnabled(true);
            bmesh.isVisible = true;
            bmesh.visibility = 1.0;
            bmesh.renderingGroupId = 0;
            touched++;
            continue;
          }
          var bex = bmesh.material;
          if (bex) {
            var bmats = bex.subMaterials || [bex];
            for (var bmi = 0; bmi < bmats.length; bmi++) {
              var bem = bmats[bmi];
              if (!bem) continue;
              bem.backFaceCulling = false;
              // Produkte: kein Emissive / Glow
              if (isProductMeshName(bnm)) {
                try {
                  if (bem.emissiveColor) bem.emissiveColor = new BABYLON.Color3(0, 0, 0);
                  if (bem.emissiveIntensity !== undefined) bem.emissiveIntensity = 0;
                } catch (eEm) {}
                // Getränke-PET nie als Transparent sortieren
                var pmn = (bem.name || '').toLowerCase();
                if (pmn.indexOf('pet') >= 0 || pmn.indexOf('cap') >= 0 ||
                    pmn.indexOf('label') >= 0 || pmn.indexOf('can') >= 0) {
                  bem.alpha = 1.0;
                  makeOpaque(bem);
                  if (bem.forceDepthWrite !== undefined) bem.forceDepthWrite = true;
                  if (bem.roughness !== undefined) bem.roughness = Math.max(bem.roughness || 0, 0.22);
                }
              }
              if (bem.environmentIntensity !== undefined) {
                var envCap = (bnm.indexOf('ControlPanel') >= 0 || bnm.indexOf('RightPanel') >= 0 ||
                  bnm.indexOf('LeftBody') >= 0 || bnm.indexOf('Roof') >= 0 ||
                  bnm.indexOf('CoinMod') >= 0 || bnm.indexOf('CornerCap') >= 0 ||
                  bnm.indexOf('Delivery') >= 0) ? 0.42 : (p.env * 0.65);
                if (isProductMeshName(bnm)) envCap = Math.min(envCap, 0.35);
                bem.environmentIntensity = Math.min(Math.max(bem.environmentIntensity || 0, envCap * 0.4), envCap);
              }
              if (bem.roughness !== undefined && (bnm.indexOf('ControlPanel') >= 0 || bnm.indexOf('RightPanel') >= 0 ||
                  bnm.indexOf('LeftBody') >= 0 || bnm.indexOf('CoinMod') >= 0 || bnm.indexOf('Roof') >= 0 ||
                  bnm.indexOf('Delivery') >= 0 || bnm.indexOf('CornerCap') >= 0)) {
                bem.roughness = Math.max(bem.roughness || 0, 0.48);
              }
              // PUSH / Labels / Screens wie exportiert; versehentliches Alpha schliessen.
              var bn = (bem.name || '').toLowerCase();
              if (bn.indexOf('glass') < 0 && bn.indexOf('push') < 0 &&
                  bem.alpha != null && bem.alpha < 0.99 && bem.alpha > 0.2) {
                bem.alpha = 1.0;
                makeOpaque(bem);
              }
            }
          }
          bmesh.visibility = 1.0;
          bmesh.setEnabled(true);
          bmesh.isVisible = true;
          if (!isMainGlass) bmesh.renderingGroupId = 0;
          touched++;
        } catch (e) {}
      }
      console.log('[JS] applyVendingMaterialStyle', style, 'preserve', 'touched', touched);
      return JSON.stringify({ ok: true, style: style, touched: touched, preserveAll: true });
    }
    for (var i = 0; i < scene.meshes.length; i++) {
      var mesh = scene.meshes[i];
      if (!mesh || !mesh.name || !mesh.getTotalVertices || mesh.getTotalVertices() < 3) continue;
      var nm = mesh.name;
      try {
        if (isGlassName(nm)) {
          var gmat = new BABYLON.PBRMaterial('VendingGlass_' + style + '_' + i, scene);
          gmat.albedoColor = new BABYLON.Color3(p.glassAlbedo[0], p.glassAlbedo[1], p.glassAlbedo[2]);
          gmat.alpha = p.glassAlpha;
          gmat.metallic = 0.0;
          gmat.roughness = 0.28;
          gmat.environmentIntensity = 0.03;
          gmat.reflectivityColor = new BABYLON.Color3(0.02, 0.02, 0.03);
          gmat.transparencyMode = BABYLON.Material.MATERIAL_ALPHABLEND;
          gmat.backFaceCulling = false;
          gmat.disableDepthWrite = false;
          mesh.material = gmat;
          mesh.visibility = 1.0;
          mesh.isVisible = true;
          // Glas nach undurchsichtigem Gehäuse zeichnen, damit keine Löcher entstehen.
          mesh.renderingGroupId = 1;
          touched++;
          continue;
        }
        // Entnahmeklappe: Multi-Material-PUSH-Lettering behalten, nur Opacity versiegeln.
        if (isDeliveryFlapDoorName(nm)) {
          var dmat = mesh.material;
          var dmats = dmat && dmat.subMaterials ? dmat.subMaterials : (dmat ? [dmat] : []);
          for (var di = 0; di < dmats.length; di++) {
            if (dmats[di]) makeOpaque(dmats[di]);
          }
          mesh.visibility = 1.0;
          mesh.setEnabled(true);
          mesh.isVisible = true;
          mesh.renderingGroupId = 0;
          touched++;
          continue;
        }
        // PolyHaven-/gebackene PBR-Texturen aus dem GLB erhalten — nur Opacity setzen.
        if ((isShellName(nm) || isFlapName(nm)) && hasAlbedoTex(mesh)) {
          var existingTex = mesh.material;
          var texMats = existingTex.subMaterials || [existingTex];
          for (var tmi = 0; tmi < texMats.length; tmi++) {
            if (texMats[tmi]) {
              makeOpaque(texMats[tmi]);
              if (texMats[tmi].environmentIntensity !== undefined) {
                texMats[tmi].environmentIntensity = Math.max(texMats[tmi].environmentIntensity || 0, p.env * 0.85);
              }
            }
          }
          mesh.visibility = 1.0;
          mesh.setEnabled(true);
          mesh.isVisible = true;
          mesh.alphaIndex = 0;
          mesh.renderingGroupId = 0;
          touched++;
          continue;
        }
        if (isFlapName(nm)) {
          var fmat = new BABYLON.PBRMaterial('VendingFlap_' + style + '_' + i, scene);
          fmat.albedoColor = new BABYLON.Color3(p.flapAlbedo[0], p.flapAlbedo[1], p.flapAlbedo[2]);
          fmat.metallic = p.flapMetal;
          fmat.roughness = p.flapRough;
          fmat.environmentIntensity = p.env;
          makeOpaque(fmat);
          mesh.material = fmat;
          mesh.visibility = 1.0;
          mesh.setEnabled(true);
          mesh.isVisible = true;
          mesh.renderingGroupId = 0;
          touched++;
          continue;
        }
        if (isShellName(nm)) {
          var smat = new BABYLON.PBRMaterial('VendingShell_' + style + '_' + i, scene);
          smat.albedoColor = new BABYLON.Color3(p.shellAlbedo[0], p.shellAlbedo[1], p.shellAlbedo[2]);
          smat.metallic = p.shellMetal;
          smat.roughness = p.shellRough;
          smat.environmentIntensity = p.env;
          smat.specularIntensity = 1.0;
          makeOpaque(smat);
          mesh.material = smat;
          mesh.visibility = 1.0;
          mesh.setEnabled(true);
          mesh.isVisible = true;
          // Sortier-Artefakte vermeiden, die Loecher ins Gehaeuse stanzen.
          mesh.alphaIndex = 0;
          mesh.renderingGroupId = 0;
          touched++;
          continue;
        }
        // Verbleibende Nicht-Produkt-Meshes mit Alpha-Import → undurchsichtig erzwingen.
        var low = nm.toLowerCase();
        if (low.indexOf('product') >= 0 || low.indexOf('motor') >= 0 ||
            low.indexOf('divider') >= 0 || low.indexOf('label') >= 0 ||
            low.indexOf('__root__') >= 0) continue;
        var existing = mesh.material;
        if (existing) {
          var mats = existing.subMaterials || [existing];
          for (var mi = 0; mi < mats.length; mi++) {
            var em = mats[mi];
            if (!em) continue;
            if (em.alpha != null && em.alpha < 0.99) {
              em.alpha = 1.0;
              makeOpaque(em);
              touched++;
            } else {
              em.backFaceCulling = false;
            }
          }
        }
      } catch (e) {}
    }
    console.log('[JS] applyVendingMaterialStyle', style, 'touched', touched);
    return JSON.stringify({ ok: true, style: style, touched: touched });
  };

  window.clampVendingCamera = function() {
    if (!window.scene || !window.scene.activeCamera) return;
    var cam = window.scene.activeCamera;
    var g = window._vendingCamGuard;
    if (!g) return;
    if (cam.mode === BABYLON.Camera.ORTHOGRAPHIC_CAMERA) {
      if (g.minRadius != null) {
        cam.radius = g.minRadius;
        cam.lowerRadiusLimit = g.minRadius;
        cam.upperRadiusLimit = g.minRadius;
      }
      return;
    }
    if (g.minRadius != null) {
      cam.lowerRadiusLimit = g.minRadius;
      if (cam.radius < g.minRadius) cam.radius = g.minRadius;
    }
    if (g.minBeta != null && cam.beta < g.minBeta) cam.beta = g.minBeta;
    if (g.maxBeta != null && cam.beta > g.maxBeta) cam.beta = g.maxBeta;
    // Orbit-Ziel nahe Automatenmitte — Pan darf nicht in den Schrank.
    var t = cam.getTarget();
    var dx = t.x - g.cx, dy = t.y - g.cy, dz = t.z - g.cz;
    var maxOff = g.maxTargetOff != null ? g.maxTargetOff : 0.35;
    var len = Math.sqrt(dx * dx + dy * dy + dz * dz);
    if (len > maxOff && len > 1e-6) {
      var s = maxOff / len;
      cam.setTarget(new BABYLON.Vector3(g.cx + dx * s, g.cy + dy * s, g.cz + dz * s));
    }
  };

  window.ensureVendingCameraGuard = function() {
    if (!window.scene || window._vendingCamGuardBound) return;
    window._vendingCamGuardBound = true;
    window.scene.onBeforeRenderObservable.add(function() {
      try { window.clampVendingCamera(); } catch (e) {}
    });
  };

  window.bindScreenRectToWorld = function(left, top, width, height, vw, vh) {
    var x0 = left * vw, y0 = top * vh;
    var x1 = (left + width) * vw, y1 = (top + height) * vh;
    var tl = resolvePoint(x0, y0);
    var tr = resolvePoint(x1, y0);
    var br = resolvePoint(x1, y1);
    var bl = resolvePoint(x0, y1);
    if (!tl || !tr || !br || !bl) return JSON.stringify({ ok: false });
    return JSON.stringify({
      ok: true,
      tl: { x: tl.x, y: tl.y, z: tl.z },
      tr: { x: tr.x, y: tr.y, z: tr.z },
      br: { x: br.x, y: br.y, z: br.z },
      bl: { x: bl.x, y: bl.y, z: bl.z }
    });
  };

  // Telemetry + ViewMatrix → Flutter (inkl. Target für Pan!)
  var _last = { alpha: null, beta: null, radius: null, ortho: null, tx: null, ty: null, tz: null };
  window.reportCameraTelemetry = function(force) {
    if (!window.scene || !window.scene.activeCamera) return;
    var cam = window.scene.activeCamera;
    var ortho = (typeof window._power3dOrthoHalf === 'number') ? window._power3dOrthoHalf : null;
    var t = cam.getTarget();
    if (!force &&
        _last.alpha != null &&
        Math.abs(cam.alpha - _last.alpha) < 0.0005 &&
        Math.abs(cam.beta - _last.beta) < 0.0005 &&
        Math.abs(cam.radius - _last.radius) < 0.001 &&
        Math.abs(t.x - (_last.tx || 0)) < 0.0004 &&
        Math.abs(t.y - (_last.ty || 0)) < 0.0004 &&
        Math.abs(t.z - (_last.tz || 0)) < 0.0004 &&
        ((ortho == null && _last.ortho == null) || (ortho != null && _last.ortho != null && Math.abs(ortho - _last.ortho) < 0.0004))) {
      return;
    }
    _last = { alpha: cam.alpha, beta: cam.beta, radius: cam.radius, ortho: ortho, tx: t.x, ty: t.y, tz: t.z };
    if (typeof sendMessageToFlutter === 'function') {
      sendMessageToFlutter({
        type: 'camera',
        alpha: cam.alpha,
        beta: cam.beta,
        radius: cam.radius,
        orthoHalf: ortho,
        tx: t.x,
        ty: t.y,
        tz: t.z
      });
    }
  };

  function hookCameraObservable() {
    if (!window.scene || !window.scene.activeCamera) return;
    var cam = window.scene.activeCamera;
    if (cam._power3dViewHook) return;
    cam._power3dViewHook = true;
    cam.onViewMatrixChangedObservable.add(function(){
      reportCameraTelemetry(true);
    });
  }
  hookCameraObservable();
  setTimeout(hookCameraObservable, 300);
  setTimeout(hookCameraObservable, 1000);

  function bindCursorZoom() {
    var canvas = window.scene && window.scene.getEngine && window.scene.getEngine().getRenderingCanvas();
    if (!canvas || canvas._power3dCursorZoom) return;
    canvas._power3dCursorZoom = true;
    canvas.addEventListener('wheel', function(e){
      if (!window.scene || !window.scene.activeCamera) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      var rect = canvas.getBoundingClientRect();
      zoomAtScreen(e.clientX - rect.left, e.clientY - rect.top, e.deltaY);
    }, { passive: false, capture: true });
  }
  bindCursorZoom();
  setTimeout(bindCursorZoom, 200);
  setTimeout(bindCursorZoom, 800);

  /** Pixel-Pan: dx/dy in CSS-Pixeln — 1:1 zum Cursor, keine Beschleunigung. */
  window.panByPixels = function(dx, dy) {
    if (!window.scene || !window.scene.activeCamera) return false;
    if (!isFinite(dx) || !isFinite(dy)) return false;
    // Harte Sicherheit gegen Ausreißer (auch von Flutter-Seite).
    if (Math.abs(dx) > 80 || Math.abs(dy) > 80) {
      dx = Math.max(-28, Math.min(28, dx));
      dy = Math.max(-28, Math.min(28, dy));
    }
    var cam = window.scene.activeCamera;
    cam.inertialPanningX = 0;
    cam.inertialPanningY = 0;
    cam.inertialAlphaOffset = 0;
    cam.inertialBetaOffset = 0;
    cam.inertialRadiusOffset = 0;
    var sz = canvasSize();
    var ch = Math.max(sz.ch, 64);
    var halfH;
    if (cam.mode === BABYLON.Camera.ORTHOGRAPHIC_CAMERA) {
      halfH = window._power3dOrthoHalf || cam.orthoTop || 1;
    } else {
      halfH = Math.tan(cam.fov * 0.5) * Math.max(cam.radius, 0.01);
    }
    if (!isFinite(halfH) || halfH <= 0) halfH = 1;
    var worldPerPx = (2 * halfH) / ch;
    var moveX = dx * worldPerPx;
    var moveY = dy * worldPerPx;
    var view = cam.getViewMatrix();
    var inv = BABYLON.Matrix.Invert(view);
    var right = BABYLON.Vector3.TransformNormal(BABYLON.Axis.X, inv).normalize();
    var up = BABYLON.Vector3.TransformNormal(BABYLON.Axis.Y, inv).normalize();
    var target = cam.getTarget().clone();
    // Ziehen nach rechts → Szene folgt Finger → Target nach links
    target.subtractInPlace(right.scale(moveX));
    target.addInPlace(up.scale(moveY));
    cam.setTarget(target);
    if (typeof window.clampVendingCamera === 'function') window.clampVendingCamera();
    try { reportCameraTelemetry(true); } catch (e) {}
    return true;
  };

  /**
   * Smooth Left-Drag-Pan (Orbit-Lock):
   * - Babylon-Default-Pan aus (springt bei schnellen Moves / Inertia)
   * - nur relative Deltas seit letztem Event
   * - Delta pro Event gecappt → kein Wegfliegen bei schnellem Ziehen
   * - echte Teleports (Pointer verloren/Overlay) werden verworfen
   */
  window.setupSmoothLeftPan = function(enabled) {
    var canvas = window.scene && window.scene.getEngine && window.scene.getEngine().getRenderingCanvas();
    if (!canvas) return false;

    if (canvas._power3dSmoothPanHandlers) {
      var h = canvas._power3dSmoothPanHandlers;
      canvas.removeEventListener('pointerdown', h.down, true);
      canvas.removeEventListener('pointermove', h.move, true);
      canvas.removeEventListener('pointerup', h.up, true);
      canvas.removeEventListener('pointercancel', h.up, true);
      window.removeEventListener('pointermove', h.winMove, true);
      window.removeEventListener('pointerup', h.up, true);
      window.removeEventListener('pointercancel', h.up, true);
      canvas._power3dSmoothPanHandlers = null;
    }
    window._power3dSmoothPanEnabled = !!enabled;
    if (!enabled) return true;

    var dragging = false;
    var lastX = 0, lastY = 0;
    var pointerId = null;
    var MAX_STEP = 18;       // px/Event — Stück für Stück wie in einer Canvas
    var JUMP_TELEPORT = 160; // nur echte Sprünge verwerfen

    function applyDelta(clientX, clientY) {
      var dx = clientX - lastX;
      var dy = clientY - lastY;
      lastX = clientX;
      lastY = clientY;
      if (!isFinite(dx) || !isFinite(dy)) return;
      // Teleport (Fokusprung / Overlay-Wechsel) → Position merken, nicht panen
      if (Math.abs(dx) > JUMP_TELEPORT || Math.abs(dy) > JUMP_TELEPORT) return;
      if (dx === 0 && dy === 0) return;
      // Schnelles Ziehen: cap statt multiplizieren → kein Wegfliegen
      dx = Math.max(-MAX_STEP, Math.min(MAX_STEP, dx));
      dy = Math.max(-MAX_STEP, Math.min(MAX_STEP, dy));
      panByPixels(dx, dy);
    }

    function onDown(e) {
      if (!window._power3dSmoothPanEnabled) return;
      if (e.button !== 0) return;
      dragging = true;
      pointerId = e.pointerId;
      lastX = e.clientX;
      lastY = e.clientY;
      try { canvas.setPointerCapture(e.pointerId); } catch (err) {}
      e.preventDefault();
      e.stopPropagation();
    }
    function onMove(e) {
      if (!dragging || !window._power3dSmoothPanEnabled) return;
      if (pointerId != null && e.pointerId !== pointerId) return;
      applyDelta(e.clientX, e.clientY);
      e.preventDefault();
    }
    function onWinMove(e) {
      // Weiter panen auch wenn Cursor kurz über Flutter-Overlay ist (Capture verloren).
      if (!dragging || !window._power3dSmoothPanEnabled) return;
      if (pointerId != null && e.pointerId !== pointerId) return;
      applyDelta(e.clientX, e.clientY);
    }
    function onUp(e) {
      if (!dragging) return;
      if (e && pointerId != null && e.pointerId !== pointerId) return;
      dragging = false;
      if (pointerId != null) {
        try { canvas.releasePointerCapture(pointerId); } catch (err) {}
      }
      pointerId = null;
    }

    canvas._power3dSmoothPanHandlers = {
      down: onDown, move: onMove, up: onUp, winMove: onWinMove
    };
    canvas.addEventListener('pointerdown', onDown, true);
    canvas.addEventListener('pointermove', onMove, true);
    canvas.addEventListener('pointerup', onUp, true);
    canvas.addEventListener('pointercancel', onUp, true);
    // lostpointercapture bewusst NICHT → Up: Drag läuft über window weiter
    // (Cursor über Flutter-Hotspot), bis pointerup.
    window.addEventListener('pointermove', onWinMove, true);
    window.addEventListener('pointerup', onUp, true);
    window.addEventListener('pointercancel', onUp, true);
    return true;
  };

  window.updateVendingHudOled = function(payload) {
    if (!window.scene) return JSON.stringify({ ok: false, reason: 'no_scene' });
    var scene = window.scene;
    var p = payload || {};
    var phase = p.phase || 'idle';
    var title = p.title || 'WÄHLE DEIN PRODUKT';
    var subtitle = p.subtitle || 'Code eingeben  ·  z. B. A1';
    var footer = p.footer || 'Münzen einwerfen · Preis bezahlen';
    var led = p.led || '#00F2FE';
    var slot = p.slot || '';
    var product = p.product || '';
    var price = p.price || '';
    var inserted = p.inserted || '';
    var missing = p.missing || '';
    var status = p.status || '';

    var mesh = null;
    for (var i = 0; i < scene.meshes.length; i++) {
      var m = scene.meshes[i];
      if (!m || !m.name) continue;
      if (m.name.indexOf('HUD_Screen') >= 0 && m.name.indexOf('Glass') < 0) {
        mesh = m;
        break;
      }
    }
    if (!mesh) return JSON.stringify({ ok: false, reason: 'no_hud_screen' });

    var W = 1024, H = 384;
    if (!scene._vendingHudDyn) {
      scene._vendingHudDyn = new BABYLON.DynamicTexture('VendingHudOledTex', { width: W, height: H }, scene, false);
      scene._vendingHudDyn.hasAlpha = false;
      scene._vendingHudMat = new BABYLON.PBRMaterial('VendingHudOledMat', scene);
      scene._vendingHudMat.albedoTexture = scene._vendingHudDyn;
      scene._vendingHudMat.emissiveTexture = scene._vendingHudDyn;
      scene._vendingHudMat.emissiveColor = new BABYLON.Color3(1, 1, 1);
      scene._vendingHudMat.metallic = 0.0;
      scene._vendingHudMat.roughness = 1.0;
      scene._vendingHudMat.environmentIntensity = 0.0;
      scene._vendingHudMat.albedoColor = new BABYLON.Color3(1, 1, 1);
      scene._vendingHudMat.backFaceCulling = false;
      scene._vendingHudMat.transparencyMode = BABYLON.Material.MATERIAL_OPAQUE;
      try { scene._vendingHudMat.disableLighting = true; } catch (e) {}
    }
    mesh.material = scene._vendingHudMat;
    mesh.setEnabled(true);
    mesh.isVisible = true;
    mesh.visibility = 1.0;
    mesh.renderingGroupId = 0;

    var ctx = scene._vendingHudDyn.getContext();
    // Hintergrund wie SNACK-OLED
    ctx.fillStyle = '#0D1117';
    ctx.fillRect(0, 0, W, H);
    // Cyan-Rahmen
    ctx.strokeStyle = 'rgba(0,242,254,0.35)';
    ctx.lineWidth = 6;
    ctx.strokeRect(10, 10, W - 20, H - 20);

    // Kopfzeile
    ctx.fillStyle = 'rgba(0,242,254,0.9)';
    ctx.font = 'bold 28px Segoe UI, Arial, sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText('SNACK · OLED', 48, 58);
    // LED
    ctx.beginPath();
    ctx.fillStyle = led;
    ctx.arc(W - 56, 48, 12, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowColor = led;
    ctx.shadowBlur = 18;
    ctx.fill();
    ctx.shadowBlur = 0;

    ctx.textAlign = 'center';
    if (phase === 'typing') {
      ctx.fillStyle = 'rgba(0,242,254,0.75)';
      ctx.font = 'bold 26px Segoe UI, Arial, sans-serif';
      ctx.fillText('SLOT', W / 2, 130);
      ctx.fillStyle = '#00FF87';
      ctx.font = 'bold 120px Segoe UI, Arial, sans-serif';
      ctx.fillText(slot || '·', W / 2, 250);
      ctx.fillStyle = '#8B949E';
      ctx.font = '28px Segoe UI, Arial, sans-serif';
      ctx.fillText(subtitle || 'Produktcode fortsetzen…', W / 2, 320);
    } else if (phase === 'selected' || phase === 'payment') {
      ctx.textAlign = 'left';
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 36px Segoe UI, Arial, sans-serif';
      var line1 = (slot ? (slot + '  ·  ') : '') + (product || '—');
      ctx.fillText(line1.substring(0, 42), 56, 140);
      ctx.fillStyle = '#FFD200';
      ctx.font = 'bold 48px Segoe UI, Arial, sans-serif';
      ctx.fillText(price || '', 56, 210);
      ctx.fillStyle = '#8B949E';
      ctx.font = '28px Segoe UI, Arial, sans-serif';
      ctx.fillText('Eingeworfen: ' + (inserted || '0,00 €'), 56, 270);
      ctx.fillStyle = phase === 'payment' ? '#FFD200' : '#00F2FE';
      ctx.font = 'bold 30px Segoe UI, Arial, sans-serif';
      ctx.fillText(missing ? ('Noch: ' + missing) : (title || ''), 56, 325);
    } else if (phase === 'dispensing') {
      ctx.fillStyle = '#00F2FE';
      ctx.font = 'bold 54px Segoe UI, Arial, sans-serif';
      ctx.fillText(title || 'AUSGABE…', W / 2, 200);
      ctx.fillStyle = '#8B949E';
      ctx.font = '28px Segoe UI, Arial, sans-serif';
      ctx.fillText(subtitle || 'Bitte warten', W / 2, 270);
    } else if (phase === 'success') {
      ctx.fillStyle = '#00FF87';
      ctx.font = 'bold 54px Segoe UI, Arial, sans-serif';
      ctx.fillText(title || 'VIELEN DANK', W / 2, 200);
      ctx.fillStyle = '#8B949E';
      ctx.font = '28px Segoe UI, Arial, sans-serif';
      ctx.fillText(subtitle || footer || '', W / 2, 270);
    } else if (phase === 'outOfService') {
      ctx.fillStyle = '#FF4D6D';
      ctx.font = 'bold 48px Segoe UI, Arial, sans-serif';
      ctx.fillText(title || 'AUSSER BETRIEB', W / 2, 210);
    } else {
      // idle — spiegelt SNACK-OLED
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 52px Segoe UI, Arial, sans-serif';
      ctx.fillText(title || 'WÄHLE DEIN PRODUKT', W / 2, 175);
      ctx.fillStyle = 'rgba(0,242,254,0.9)';
      ctx.font = 'bold 30px Segoe UI, Arial, sans-serif';
      ctx.fillText(subtitle || 'Code eingeben  ·  z. B. A1', W / 2, 245);
      ctx.fillStyle = '#8B949E';
      ctx.font = '26px Segoe UI, Arial, sans-serif';
      ctx.fillText(footer || 'Münzen einwerfen · Preis bezahlen', W / 2, 305);
      if (status && status.length > 0 && status.indexOf('Bitte Produkt') < 0) {
        ctx.fillStyle = '#FF4D6D';
        ctx.font = 'bold 24px Segoe UI, Arial, sans-serif';
        ctx.fillText(status.substring(0, 60), W / 2, 345);
      }
    }

    scene._vendingHudDyn.update();
    scene._vendingHudOled = true;
    return JSON.stringify({ ok: true, phase: phase, mesh: mesh.name });
  };

  window._power3dProjectionReady = true;
  window._power3dProjectionVer = 12;
  return true;
})()
''';
