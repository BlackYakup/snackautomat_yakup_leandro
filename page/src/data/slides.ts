export type Slide =
  | {
      id: string;
      kind: "title";
      title: string;
      subtitle: string;
      meta: string;
      speakHint: string;
    }
  | {
      id: string;
      kind: "explain";
      title: string;
      kicker: string;
      points: string[];
      image?: string;
      speakHint: string;
    }
  | {
      id: string;
      kind: "diagram";
      title: string;
      kicker: string;
      image: string;
      caption: string;
      speakHint: string;
    }
  | {
      id: string;
      kind: "flow";
      title: string;
      kicker: string;
      caption: string;
      steps: { label: string; tone: "green" | "blue" | "yellow" | "neutral" }[];
      transitions: string[];
      speakHint: string;
    }
  | {
      id: string;
      kind: "code";
      title: string;
      kicker: string;
      file: string;
      tags: string[];
      explanation: string[];
      code: string[];
      speakHint: string;
    }
  | {
      id: string;
      kind: "status";
      title: string;
      kicker: string;
      intro: string;
      now: { title: string; detail: string }[];
      next: { title: string; detail: string }[];
      speakHint: string;
    }
  | {
      id: string;
      kind: "closing";
      title: string;
      lines: string[];
      speakHint: string;
    };

/** ~5-6 Minuten - Diagramme + echte Dart-Steuerung (ohne Live-3D) */
export const SLIDES: Slide[] = [
  {
    id: "title",
    kind: "title",
    title: "Snackautomat 3D",
    subtitle: "Wie Flutter das GLB steuert · Zonen · Slots · echte Dart-API",
    meta: "Yakup & Leandro  ·  ca. 5–6 Minuten  ·  14 Folien",
    speakHint: "Heute: Naming, Slot-Codes und wie Dart das Modell lenkt – ohne Live-Viewer.",
  },
  {
    id: "goal",
    kind: "explain",
    kicker: "Ziel",
    title: "Eine gemeinsame Sprache: Mesh ↔ App",
    points: [
      "Blender exportiert benannte Baugruppen ins GLB",
      "Flutter lädt das GLB in Power3D (Babylon in der WebView)",
      "Riverpod-Session ruft Dart-API → JS Eval auf den Meshes",
      "Slot-Codes wie A1 verbinden Kauf-Logik und sichtbaren Stock",
    ],
    image: "/diagrams/diagram_flutter_3d.png",
    speakHint: "Kein Live-Blender beim Kauf – nur GLB + Controller.",
  },
  {
    id: "zones",
    kind: "diagram",
    kicker: "Aufbau",
    title: "Zonen am Automaten",
    image: "/diagrams/diagram_zones.png",
    caption:
      "Produktbereich · PUSH-Klappe · rechts Control Panel (HUD, ePort, Keypad, CoinMod, Coin Return).",
    speakHint: "Landkarte: welche Zone später welchen Prefix und welche API hat.",
  },
  {
    id: "naming",
    kind: "diagram",
    kicker: "Naming",
    title: "Objekt-Prefixes = Steuer-Handles",
    image: "/diagrams/diagram_naming.png",
    caption:
      "KP_* · EPort_* · CoinMod_* · CoinReturn_* · UI_HUD_* · DeliveryFlap – gleiche Namen in Blend, GLB und JS.",
    speakHint: "Ohne stabile Namen keine gezielte Klappe/Stock/Kamera.",
  },
  {
    id: "slots",
    kind: "diagram",
    kicker: "Slots",
    title: "Slot-Code A1–F10",
    image: "/diagrams/diagram_slots.png",
    caption:
      "rowLabel + columnNumber → z. B. C4. Dieselbe Zeichenkette in Sidebar, SQLite und dispenseItem.",
    speakHint: "Kunde tippt C4 – 3D sucht Product_C04_* / Motor_C4_Spiral.",
  },
  {
    id: "domain",
    kind: "diagram",
    kicker: "Domain",
    title: "Product ≠ Slot ≠ PlacedProduct",
    image: "/diagrams/diagram_domain.png",
    caption:
      "Katalog, physische Belegung und Joined-Sicht für Stock-Sync – Grundlage für syncVendingStock.",
    speakHint: "Admin ändert Slot/Stock → Map → 3D-Sichtbarkeit.",
  },
  {
    id: "load",
    kind: "code",
    kicker: "Laden",
    title: "GLB in Flutter einbinden",
    file: "vending_machine_3d_landing_screen.dart",
    tags: ["fromAsset", "Controller", "GLB", "WebView"],
    explanation: [
      "Controller hält den Viewer-Zustand.",
      "fromAsset lädt das Automaten-GLB.",
      "onModelLoaded startet Setup + Stock-Sync.",
      "Nur eine aktive Viewer-Instanz.",
    ],
    code: [
      "static const modelAsset =",
      "    'assets/models/vending_machine_front.glb';",
      "",
      "Power3DController? _controller;",
      "",
      "Power3D.fromAsset(",
      "  VendingMachine3DLandingScreen.modelAsset,",
      "  controller: _controller,",
      "  onModelLoaded: () => unawaited(_onModelLoaded()),",
      "  zoomSensitivity: 0.55,",
      ");",
    ],
    speakHint: "Einstieg: Widget + Controller, kein HTTP zu Blender.",
  },
  {
    id: "bridge",
    kind: "code",
    kicker: "Brücke",
    title: "Dart ruft Babylon-JS auf",
    file: "packages/power3d · projection_extension.dart",
    tags: ["_evalJs", "Klappe", "Mesh", "Wrapper"],
    explanation: [
      "_evalJs sendet Code in die WebView.",
      "Dart-API wrappt window.*-Funktionen.",
      "Klappe steuert Vending_DeliveryFlap_Door.",
      "Logik in Dart, Animation in Babylon.",
    ],
    code: [
      "/// Oeffnet/schliesst die Klappe (Vending_DeliveryFlap_Door)",
      "Future<bool> setDeliveryFlapOpen(",
      "  bool open, {",
      "  double angleDeg = 42,",
      "}) async {",
      "  if (!_alive) return false;",
      "  await ensureProjectionHelpers();",
      "  final raw = await _evalJs(",
      "    'setDeliveryFlapOpen(${open ? 'true' : 'false'}, $angleDeg)',",
      "  );",
      "  return _parseJsJsonMap(raw)?['ok'] == true;",
      "}",
    ],
    speakHint: "Muster für fast alle Steuerungen: Dart-API → _evalJs → Mesh.",
  },
  {
    id: "camera",
    kind: "code",
    kicker: "Kamera",
    title: "Presets: front / buy / dispense",
    file: "landing + view_extension.dart",
    tags: ["Kamera", "Presets", "buy", "dispense"],
    explanation: [
      "UI wählt viewId, Landing ruft die API.",
      "JS rahmt Meshes nach Prefix.",
      "buy = Control Panel, dispense = Ausgabe.",
      "Orbit-Lock hält die Demo stabil.",
    ],
    code: [
      "Future<void> _applyCameraView(String viewId) async {",
      "  final c = _controller;",
      "  if (c == null) return;",
      "  await c.applyVendingCameraView(viewId);",
      "  // 'front' | 'front3d' | 'buy' | 'product' | 'dispense'",
      "}",
      "",
      "// Power3D: Dart -> JS-Kamera auf Shell/Zone",
      "Future<void> applyVendingCameraView(String viewId) async {",
      "  await _evalJs(/* Kamera an Mesh-Bounding-Box */);",
      "}",
    ],
    speakHint: "Präsentation und Kauf nutzen dieselben Presets.",
  },
  {
    id: "stock",
    kind: "code",
    kicker: "Lager → Mesh",
    title: "syncVendingStock",
    file: "landing + projection_extension.dart",
    tags: ["Stock", "Map A1→N", "Product_*", "SQLite"],
    explanation: [
      "PlacedProduct kommt aus SQLite.",
      "Map {'A1': 3, …} für sichtbare Stacks.",
      "JS blendet Product_*_s00… ein/aus.",
      "Nach Kauf/Refill erneut syncen.",
    ],
    code: [
      "Future<void> _syncStock(List<PlacedProduct> placed) async {",
      "  final map = stockBySlotFromPlaced(placed);",
      "  await _controller!.syncVendingStock(map);",
      "}",
      "",
      "Future<void> syncVendingStock(",
      "  Map<String, int> stockBySlot,",
      ") async {",
      "  await _evalJs(",
      "    'syncVendingStock(${jsonEncode(stockBySlot)})',",
      "  );",
      "}",
    ],
    speakHint: "Sichtbarer Stock = Domain-Stock, nicht Hardcode im Mesh.",
  },
  {
    id: "dispense-session",
    kind: "code",
    kicker: "Kauf → 3D",
    title: "Session ruft den Dispense-Handler",
    file: "providers/provider.dart",
    tags: ["dispensing", "Handler", "Stock−1", "Session"],
    explanation: [
      "Phase wechselt auf dispensing.",
      "Handler kommt vom Landing-Screen.",
      "Zuerst Animation, dann Stock −1.",
      "Ohne Handler: kurzer 2D-Fallback.",
    ],
    code: [
      "state = state.copyWith(",
      "  phase: VendingMachinePhase.dispensing,",
      "  selectedSlotCode: slotCode,",
      ");",
      "",
      "final handler = dispenseAnimationHandler;",
      "if (handler != null) {",
      "  await handler(slotCode, visibleStock);",
      "} else {",
      "  await Future.delayed(const Duration(milliseconds: 350));",
      "}",
      "",
      "await placedProductsProvider.notifier",
      "    .decreaseStockAfterPurchase(placed);",
    ],
    speakHint: "Trennung: Session kennt Kauf, Landing kennt Meshes.",
  },
  {
    id: "dispense-3d",
    kind: "code",
    kicker: "Ausgabe",
    title: "Handler: dispenseItem + Flap",
    file: "vending_machine_3d_landing_screen.dart",
    tags: ["dispenseItem", "Flap", "Slot-Code", "5600 ms"],
    explanation: [
      "Callback am Session-Notifier.",
      "dispenseItem startet Aufzug/Spirale.",
      "Danach Klappe öffnen zum Entnehmen.",
      "Slot-Code = Sidebar-Code (z. B. A1).",
    ],
    code: [
      "dispenseAnimationHandler =",
      "    (slotCode, visibleStock) async {",
      "  final ok = await c.dispenseItem(",
      "    slotCode,",
      "    visibleStock: visibleStock,",
      "    durationMs: 5600,",
      "  );",
      "  await c.setDeliveryFlapOpen(true, angleDeg: 36);",
      "};",
      "",
      "// Power3D.dispenseItem -> JS:",
      "// dispenseVendingItem(slotCode, stock, ms)",
    ],
    speakHint: "Hoehepunkt: ein String-Slot steuert die ganze 3D-Sequenz.",
  },
  {
    id: "phases",
    kind: "flow",
    kicker: "Ablauf",
    title: "Kaufablauf / Phasen",
    caption: "LED-Farben spiegeln die Phase. Sperren gelten in UI und Logik.",
    steps: [
      { label: "BEREIT", tone: "green" },
      { label: "ZAHLUNG", tone: "blue" },
      { label: "AUSGABE", tone: "yellow" },
      { label: "DANKE", tone: "neutral" },
      { label: "BEREIT", tone: "green" },
    ],
    transitions: ["Slot tippen", "Münzen", "Ausgabe + Klappe", "Zurücksetzen"],
    speakHint: "3D-Steuerung hängt vor allem an der Ausgabephase.",
  },
  {
    id: "ist-soll",
    kind: "status",
    kicker: "Status",
    title: "Was läuft heute – was kommt als Nächstes",
    intro:
      "IST = in der App verdrahtet und demo-fähig. SOLL = geplante Erweiterung, noch nicht produktiv gekoppelt.",
    now: [
      {
        title: "Kauf über Sidebar",
        detail: "Slot tippen → Riverpod-Session → optionaler 3D-Handler. Die Bedienung läuft über Flutter-Widgets, nicht über Mesh-Klicks.",
      },
      {
        title: "Lager sichtbar im Modell",
        detail: "syncVendingStock spiegelt PlacedProduct/SQLite auf Product_*-Meshes (Stack s00… sichtbar).",
      },
      {
        title: "Kamera & Klappe",
        detail: "Presets front/buy/dispense und setDeliveryFlapOpen steuern Blick und PUSH-Klappe.",
      },
      {
        title: "Material-Look",
        detail: "Styles wie blender_dark passen Beleuchtung/Material an – näher am Blender-Export.",
      },
    ],
    next: [
      {
        title: "Keypad per Raycast",
        detail: "Klick direkt auf KP_Key_* im Mesh soll dieselbe Session-API auslösen wie die Sidebar.",
      },
      {
        title: "Live-ePort-Screen",
        detail: "Dynamische Textur/Widget auf EPort_Screen statt Platzhalter-Material.",
      },
      {
        title: "Reichere Ausgabe",
        detail: "Längere Dispense-Sequenz mit klareren Aufzug-/Spiral-Schritten und Feedback.",
      },
      {
        title: "Optional Training-Bridge",
        detail: "Nur falls Live-Blender-Anbindung gewünscht – nicht nötig für die normale Demo.",
      },
    ],
    speakHint: "Klar sagen: Mesh-Hits auf dem Keypad sind noch Ausblick.",
  },
  {
    id: "end",
    kind: "closing",
    title: "Danke",
    lines: [
      "Steuerung = Naming + Slot-Code + Dart-Controller + JS am Mesh.",
      "Fragen zu Handler, Stock-Sync oder Klappe?",
    ],
    speakHint: "Kurz schliessen – bei Fragen Code-Folien nochmal zeigen.",
  },
];
