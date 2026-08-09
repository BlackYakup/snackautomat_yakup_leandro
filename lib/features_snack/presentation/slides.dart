// Folien-Daten der Snackautomat-Präsentation (In-App).

enum SlideKind { title, explain, diagram, flow, code, status, closing }

enum FlowTone { green, blue, yellow, neutral }

sealed class PresentationSlide {
  const PresentationSlide({
    required this.id,
    required this.kind,
    required this.speakHint,
  });

  final String id;
  final SlideKind kind;
  final String speakHint;
}

class TitleSlide extends PresentationSlide {
  const TitleSlide({
    required super.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    required super.speakHint,
  }) : super(kind: SlideKind.title);

  final String title;
  final String subtitle;
  final String meta;
}

class ExplainSlide extends PresentationSlide {
  const ExplainSlide({
    required super.id,
    required this.title,
    required this.kicker,
    required this.points,
    required super.speakHint,
    this.imageAsset,
  }) : super(kind: SlideKind.explain);

  final String title;
  final String kicker;
  final List<String> points;
  final String? imageAsset;
}

class DiagramSlide extends PresentationSlide {
  const DiagramSlide({
    required super.id,
    required this.title,
    required this.kicker,
    required this.imageAsset,
    required this.caption,
    required super.speakHint,
  }) : super(kind: SlideKind.diagram);

  final String title;
  final String kicker;
  final String imageAsset;
  final String caption;
}

class FlowStep {
  const FlowStep({required this.label, required this.tone});
  final String label;
  final FlowTone tone;
}

class FlowSlide extends PresentationSlide {
  const FlowSlide({
    required super.id,
    required this.title,
    required this.kicker,
    required this.caption,
    required this.steps,
    required this.transitions,
    required super.speakHint,
  }) : super(kind: SlideKind.flow);

  final String title;
  final String kicker;
  final String caption;
  final List<FlowStep> steps;
  final List<String> transitions;
}

class CodeSlide extends PresentationSlide {
  const CodeSlide({
    required super.id,
    required this.title,
    required this.kicker,
    required this.file,
    required this.tags,
    required this.explanation,
    required this.code,
    required super.speakHint,
    this.summary = '',
  }) : super(kind: SlideKind.code);

  final String title;
  final String kicker;
  /// Pfad ab Projekt-Root, z. B. lib/.../datei.dart
  final String file;
  final List<String> tags;
  /// Kurze Schritte in Alltagssprache.
  final List<String> explanation;
  final List<String> code;
  /// Ein Satz: Worum geht’s? (für Einsteiger)
  final String summary;
}

class StatusItem {
  const StatusItem({
    required this.title,
    required this.detail,
    this.imageAsset,
  });
  final String title;
  final String detail;
  final String? imageAsset;
}

class StatusSlide extends PresentationSlide {
  const StatusSlide({
    required super.id,
    required this.title,
    required this.kicker,
    required this.intro,
    required this.now,
    required this.next,
    required super.speakHint,
  }) : super(kind: SlideKind.status);

  final String title;
  final String kicker;
  final String intro;
  final List<StatusItem> now;
  final List<StatusItem> next;
}

class ClosingSlide extends PresentationSlide {
  const ClosingSlide({
    required super.id,
    required this.title,
    required this.lines,
    required super.speakHint,
  }) : super(kind: SlideKind.closing);

  final String title;
  final List<String> lines;
}

const kPresentationTotal = Duration(minutes: 5, seconds: 30);

const kPresentationSlides = <PresentationSlide>[
  TitleSlide(
    id: 'title',
    title: 'Snackautomat 3D',
    subtitle: 'Wie Flutter das GLB steuert · Zonen · Slots · echte Dart-API',
    meta: 'Yakup & Leandro  ·  ca. 5–6 Minuten  ·  14 Folien',
    speakHint:
        'Heute: Naming, Slot-Codes und wie Dart das Modell lenkt – ohne Live-Viewer.'
  ),
  ExplainSlide(
    id: 'goal',
    kicker: 'Ziel',
    title: 'Eine gemeinsame Sprache: Mesh ↔ App',
    points: [
      'Blender exportiert benannte Baugruppen ins GLB',
      'Flutter lädt das GLB in Power3D (Babylon in der WebView)',
      'Riverpod-Session ruft Dart-API → JS Eval auf den Meshes',
      'Slot-Codes wie A1 verbinden Kauf-Logik und sichtbaren Stock',
    ],
    imageAsset: 'assets/presentation/diagrams/diagram_flutter_3d.png',
    speakHint: 'Kein Live-Blender beim Kauf – nur GLB + Controller.'
  ),
  DiagramSlide(
    id: 'zones',
    kicker: 'Aufbau',
    title: 'Zonen am Automaten',
    imageAsset: 'assets/presentation/diagrams/diagram_zones.png',
    caption:
        'Produktbereich · PUSH-Klappe · rechts Control Panel (HUD, ePort, Keypad, CoinMod, Coin Return).',
    speakHint: 'Landkarte: welche Zone später welchen Prefix und welche API hat.'
  ),
  DiagramSlide(
    id: 'naming',
    kicker: 'Naming',
    title: 'Objekt-Prefixes = Steuer-Handles',
    imageAsset: 'assets/presentation/diagrams/diagram_naming.png',
    caption:
        'KP_* · EPort_* · CoinMod_* · CoinReturn_* · UI_HUD_* · DeliveryFlap – gleiche Namen in Blend, GLB und JS.',
    speakHint: 'Ohne stabile Namen keine gezielte Klappe/Stock/Kamera.'
  ),
  DiagramSlide(
    id: 'slots',
    kicker: 'Slots',
    title: 'Slot-Code A1–F10',
    imageAsset: 'assets/presentation/diagrams/diagram_slots.png',
    caption:
        'rowLabel + columnNumber → z. B. C4. Dieselbe Zeichenkette in Sidebar, SQLite und dispenseItem.',
    speakHint: 'Kunde tippt C4 – 3D sucht Product_C04_* / Motor_C4_Spiral.'
  ),
  DiagramSlide(
    id: 'domain',
    kicker: 'Domain',
    title: 'Product ≠ Slot ≠ PlacedProduct',
    imageAsset: 'assets/presentation/diagrams/diagram_domain.png',
    caption:
        'Katalog, physische Belegung und Joined-Sicht für Stock-Sync – Grundlage für syncVendingStock.',
    speakHint: 'Admin ändert Slot/Stock → Map → 3D-Sichtbarkeit.'
  ),
  CodeSlide(
    id: 'load',
    kicker: 'Laden',
    title: 'GLB in Flutter einbinden',
    summary:
        'Flutter lädt die 3D-Datei (GLB) einmal — danach kann die App den Automaten steuern.',
    file:
        'lib/features_snack/screens/vending_machine/vending_machine_3d_landing_screen.dart',
    tags: ['1 Datei laden', 'Controller', 'GLB', 'WebView'],
    explanation: [
      'Die Datei liegt im Projekt unter assets/… und heißt *.glb (3D-Modell).',
      'Power3D.fromAsset = „nimm diese Datei und zeig sie in der App“.',
      'Der Controller ist die Fernbedienung: darüber steuerst du Kamera, Stock, Klappe.',
      'onModelLoaded = „Modell ist fertig geladen — jetzt Setup starten“.',
    ],
    code: [
      '// === DATEI (Root):',
      '// lib/features_snack/screens/vending_machine/',
      '//   vending_machine_3d_landing_screen.dart',
      '',
      '// Pfad zur 3D-Datei im Projekt:',
      "static const modelAsset =",
      "    'assets/models/vending_machine_front.glb';",
      '',
      '// Fernbedienung fürs 3D-Modell:',
      'Power3DController? _controller;',
      '',
      '// Modell laden + anzeigen:',
      'Power3D.fromAsset(',
      '  VendingMachine3DLandingScreen.modelAsset,',
      '  controller: _controller,',
      '  onModelLoaded: () => unawaited(_onModelLoaded()),',
      '  zoomSensitivity: 0.55,',
      ');',
    ],
    speakHint: 'Einstieg: Widget + Controller, kein HTTP zu Blender.',
  ),
  CodeSlide(
    id: 'bridge',
    kicker: 'Brücke',
    title: 'Dart ruft Babylon-JS auf',
    summary:
        'Dart sagt „Klappe auf“ — dahinter läuft JavaScript in der WebView, das das Mesh dreht.',
    file: 'packages/power3d/lib/src/controller/projection_extension.dart',
    tags: ['Dart → JS', 'Klappe', 'Mesh-Name', 'Brücke'],
    explanation: [
      'Dart kennt die Kauf-Logik; Babylon/JS bewegt die 3D-Teile.',
      '_evalJs = „schick diesen Befehl in die WebView“.',
      'Der Mesh-Name muss exakt stimmen (z. B. Vending_DeliveryFlap_Door).',
      'Gleiches Muster für Kamera, Stock, Ausgabe: immer Dart-API → JS → Mesh.',
    ],
    code: [
      '// === DATEI (Root):',
      '// packages/power3d/lib/src/controller/',
      '//   projection_extension.dart',
      '',
      '// Öffnet/schließt die PUSH-Klappe am Automaten',
      'Future<bool> setDeliveryFlapOpen(',
      '  bool open, {',
      '  double angleDeg = 42, // wie weit aufklappen',
      '}) async {',
      '  if (!_alive) return false;',
      '  await ensureProjectionHelpers();',
      '  // Hier springt Dart nach JavaScript:',
      '  final raw = await _evalJs(',
      "    'setDeliveryFlapOpen(\${open ? 'true' : 'false'}, \$angleDeg)',",
      '  );',
      "  return _parseJsJsonMap(raw)?['ok'] == true;",
      '}',
    ],
    speakHint: 'Muster für fast alle Steuerungen: Dart-API → _evalJs → Mesh.',
  ),
  CodeSlide(
    id: 'camera',
    kicker: 'Kamera',
    title: 'Presets: front / buy / dispense',
    summary:
        'Ein kurzer Name („buy“, „dispense“) stellt die Kamera auf die richtige Zone.',
    file:
        'lib/features_snack/screens/vending_machine/vending_machine_3d_landing_screen.dart',
    tags: ['Kamera', 'front', 'buy', 'dispense'],
    explanation: [
      'Die UI wählt nur einen viewId-String — mehr muss der Nutzer nicht wissen.',
      'Landing ruft applyVendingCameraView auf (Power3D-API).',
      'buy = Blick aufs Bedienpanel rechts; dispense = Blick auf die Ausgabe.',
      'Zusatz-Datei: packages/power3d/lib/src/controller/view_extension.dart',
    ],
    code: [
      '// === DATEI (Root):',
      '// lib/features_snack/screens/vending_machine/',
      '//   vending_machine_3d_landing_screen.dart',
      '// (+ packages/power3d/.../view_extension.dart)',
      '',
      '// UI sagt z. B. "buy" — Landing stellt die Kamera:',
      'Future<void> _applyCameraView(String viewId) async {',
      '  final c = _controller;',
      '  if (c == null) return;',
      '  await c.applyVendingCameraView(viewId);',
      "  // erlaubt: 'front' | 'front3d' | 'buy' | 'product' | 'dispense'",
      '}',
    ],
    speakHint: 'Präsentation und Kauf nutzen dieselben Presets.',
  ),
  CodeSlide(
    id: 'stock',
    kicker: 'Lager → Mesh',
    title: 'syncVendingStock',
    summary:
        'Was in der Datenbank als Lager steht, siehst du sofort an den Produkt-Meshes.',
    file:
        'lib/features_snack/screens/vending_machine/vending_machine_3d_landing_screen.dart',
    tags: ['Lager', 'A1 → Stückzahl', 'Product_*', 'SQLite'],
    explanation: [
      'SQLite / PlacedProduct = echtes Lager in der App.',
      'Daraus wird eine Map: Slot-Code → Anzahl (z. B. A1: 3).',
      'syncVendingStock blendet die Product_*-Meshes ein oder aus.',
      'Nach jedem Kauf oder Refill erneut syncen — sonst stimmt das Bild nicht.',
    ],
    code: [
      '// === DATEI (Root):',
      '// lib/features_snack/screens/vending_machine/',
      '//   vending_machine_3d_landing_screen.dart',
      '// (+ packages/power3d/.../projection_extension.dart)',
      '',
      '// 1) Lager aus der App lesen',
      'Future<void> _syncStock(List<PlacedProduct> placed) async {',
      '  final map = stockBySlotFromPlaced(placed); // z.B. {A1: 3}',
      '  await _controller!.syncVendingStock(map);',
      '}',
      '',
      '// 2) An 3D weitergeben (Dart → JS)',
      'Future<void> syncVendingStock(',
      '  Map<String, int> stockBySlot,',
      ') async {',
      '  await _evalJs(',
      "    'syncVendingStock(\${jsonEncode(stockBySlot)})',",
      '  );',
      '}',
    ],
    speakHint: 'Sichtbarer Stock = Domain-Stock, nicht Hardcode im Mesh.',
  ),
  CodeSlide(
    id: 'dispense-session',
    kicker: 'Kauf → 3D',
    title: 'Session ruft den Dispense-Handler',
    summary:
        'Die Kauf-Session sagt nur „gib A1 aus“ — die 3D-Animation macht eine andere Datei.',
    file: 'lib/features_snack/providers/provider.dart',
    tags: ['Kauf-Phase', 'Handler', 'Stock −1', 'Session'],
    explanation: [
      'Zuerst wechselt die Phase auf „dispensing“ (Ausgabe läuft).',
      'Dann wird der Handler vom Landing-Screen aufgerufen (falls gesetzt).',
      'Erst Animation, danach Lager −1 in der Datenbank.',
      'Ohne Handler: kurze Pause — dann trotzdem Stock verringern (2D-Fallback).',
    ],
    code: [
      '// === DATEI (Root):',
      '// lib/features_snack/providers/provider.dart',
      '',
      '// Phase: wir sind in der Ausgabe',
      'state = state.copyWith(',
      '  phase: VendingMachinePhase.dispensing,',
      '  selectedSlotCode: slotCode, // z.B. "A1"',
      ');',
      '',
      '// 3D-Animation (kommt vom Landing-Screen):',
      'final handler = dispenseAnimationHandler;',
      'if (handler != null) {',
      '  await handler(slotCode, visibleStock);',
      '} else {',
      '  await Future.delayed(const Duration(milliseconds: 350));',
      '}',
      '',
      '// Danach Lager wirklich −1:',
      'await placedProductsProvider.notifier',
      '    .decreaseStockAfterPurchase(placed);',
    ],
    speakHint: 'Trennung: Session kennt Kauf, Landing kennt Meshes.',
  ),
  CodeSlide(
    id: 'dispense-3d',
    kicker: 'Ausgabe',
    title: 'Handler: dispenseItem + Flap',
    summary:
        'Ein Slot-Code (z. B. A1) startet Aufzug/Spirale und öffnet danach die Klappe.',
    file:
        'lib/features_snack/screens/vending_machine/vending_machine_3d_landing_screen.dart',
    tags: ['Ausgabe', 'Klappe', 'Slot A1', 'ca. 5,6 s'],
    explanation: [
      'Dieser Handler wird von der Session aufgerufen (siehe Folie davor).',
      'dispenseItem(slotCode) = „Dreh Spirale / fahr Aufzug für diesen Slot“.',
      'Danach setDeliveryFlapOpen(true) = „Klappe auf, Kunde kann entnehmen“.',
      'Slot-Code ist derselbe wie in der Sidebar (A1, B3, …) — ein String verbindet alles.',
    ],
    code: [
      '// === DATEI (Root):',
      '// lib/features_snack/screens/vending_machine/',
      '//   vending_machine_3d_landing_screen.dart',
      '',
      '// Wird von der Session aufgerufen, wenn jemand kauft:',
      'dispenseAnimationHandler =',
      '    (slotCode, visibleStock) async {',
      '  // 1) Produkt aus dem Fach holen (Animation)',
      '  final ok = await c.dispenseItem(',
      '    slotCode,              // z.B. "A1"',
      '    visibleStock: visibleStock,',
      '    durationMs: 5600,      // ca. 5,6 Sekunden',
      '  );',
      '  // 2) PUSH-Klappe öffnen',
      '  await c.setDeliveryFlapOpen(true, angleDeg: 36);',
      '};',
      '',
      '// Intern (Power3D → JS):',
      '// dispenseVendingItem(slotCode, stock, ms)',
    ],
    speakHint: 'Höhepunkt: ein String-Slot steuert die ganze 3D-Sequenz.',
  ),
  FlowSlide(
    id: 'phases',
    kicker: 'Ablauf',
    title: 'Kaufablauf / Phasen',
    caption:
        'Phase antippen: Display-Text + LEDs ändern sich — wie im echten HUD.',
    steps: [
      FlowStep(label: 'BEREIT', tone: FlowTone.green),
      FlowStep(label: 'ZAHLUNG', tone: FlowTone.blue),
      FlowStep(label: 'AUSGABE', tone: FlowTone.yellow),
      FlowStep(label: 'DANKE', tone: FlowTone.neutral),
    ],
    transitions: ['Slot tippen', 'Münzen', 'Ausgabe + Klappe', 'Zurücksetzen'],
    speakHint: 'Klick die Phasen — Display zeigt Titel/Unterzeile wie im Automaten.'
  ),
  StatusSlide(
    id: 'ist-soll',
    kicker: 'Status',
    title: 'Was läuft heute – was kommt als Nächstes',
    intro:
        'IST = in der App verdrahtet und demo-fähig. SOLL = geplante Erweiterung, noch nicht produktiv gekoppelt.',
    now: [
      StatusItem(
        title: 'Kauf über Sidebar',
        detail:
            'Slot tippen → Riverpod-Session → optionaler 3D-Handler. Die Bedienung läuft über Flutter-Widgets, nicht über Mesh-Klicks.',
        imageAsset: 'assets/presentation/status/ist_sidebar.png',
      ),
      StatusItem(
        title: 'Lager sichtbar im Modell',
        detail:
            'syncVendingStock spiegelt PlacedProduct/SQLite auf Product_*-Meshes (Stack s00… sichtbar).',
        imageAsset: 'assets/presentation/status/ist_stock.png',
      ),
      StatusItem(
        title: 'Kamera & Klappe',
        detail:
            'Presets front/buy/dispense und setDeliveryFlapOpen steuern Blick und PUSH-Klappe.',
        imageAsset: 'assets/presentation/status/ist_flap.png',
      ),
      StatusItem(
        title: 'Material-Look',
        detail:
            'Styles wie blender_dark passen Beleuchtung/Material an – näher am Blender-Export.',
        imageAsset: 'assets/presentation/status/ist_material.png',
      ),
    ],
    next: [
      StatusItem(
        title: 'Keypad per Raycast',
        detail:
            'Klick direkt auf KP_Key_* im Mesh soll dieselbe Session-API auslösen wie die Sidebar.',
        imageAsset: 'assets/presentation/status/soll_keypad.png',
      ),
      StatusItem(
        title: 'Live-ePort-Screen',
        detail:
            'Dynamische Textur/Widget auf EPort_Screen statt Platzhalter-Material.',
        imageAsset: 'assets/presentation/status/soll_eport.png',
      ),
      StatusItem(
        title: 'Reichere Ausgabe',
        detail:
            'Längere Dispense-Sequenz mit klareren Aufzug-/Spiral-Schritten und Feedback.',
        imageAsset: 'assets/presentation/status/soll_dispense.png',
      ),
      StatusItem(
        title: 'Optional Training-Bridge',
        detail:
            'Nur falls Live-Blender-Anbindung gewünscht – nicht nötig für die normale Demo.',
        imageAsset: 'assets/presentation/status/soll_bridge.png',
      ),
    ],
    speakHint: 'Klar sagen: Mesh-Hits auf dem Keypad sind noch Ausblick.'
  ),
  ClosingSlide(
    id: 'end',
    title: 'Danke',
    lines: [
      'Steuerung = Naming + Slot-Code + Dart-Controller + JS am Mesh.',
      'Fragen zu Handler, Stock-Sync oder Klappe?',
    ],
    speakHint: 'Kurz schliessen – bei Fragen Code-Folien nochmal zeigen.'
  ),
];
