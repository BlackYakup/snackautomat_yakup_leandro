# Snackautomat Yakup & Leandro

Interaktive Flutter-App eines Snack-/Getränkeautomaten mit realistischer **3D-Front** (GLB in Power3D / Babylon.js), voller **Kauf- und Ausgabesequenz**, **HUD-OLED-Sync**, **Admin-Bereich** und **integrierter Präsentation**.

Die Demo läuft **standalone auf Windows** — ohne Live-Anbindung an Blender. Das Automatenmodell liegt als Bundle-Asset unter [`assets/models/vending_machine_front.glb`](assets/models/vending_machine_front.glb) (~85 MB).

| | |
| --- | --- |
| Paket | `snackautomat_yakup_leandro` `1.0.0+1` |
| SDK | Dart / Flutter `^3.11.0` |
| Primärziel | Windows Desktop |
| 3D-Viewer | lokales Path-Paket [`packages/power3d`](packages/power3d) `2.3.1` |
| Persistenz | SQLite (`snackautomat.db`, Migrationen 001–010) |
| Katalog | 47 Produkt-Slugs unter `assets/products/` |
| Team | Yakup & Leandro |

---

## Inhaltsverzeichnis

1. [Projektüberblick](#projektüberblick)
2. [Was die App kann](#was-die-app-kann)
3. [Architektur](#architektur)
4. [Tech-Stack](#tech-stack)
5. [Voraussetzungen](#voraussetzungen)
6. [Installation (Windows)](#installation-windows)
7. [App starten](#app-starten)
8. [Release-Build](#release-build)
9. [Nach dem ersten Start](#nach-dem-ersten-start)
10. [Bedienung (Kurz)](#bedienung-kurz)
11. [Repository-Struktur](#repository-struktur)
12. [Kaufablauf & Mesh-Naming](#kaufablauf--mesh-naming)
13. [Dokumentation](#dokumentation)
14. [Entwicklung](#entwicklung)
15. [Troubleshooting](#troubleshooting)
16. [Lizenz / Status](#lizenz--status)

---

## Projektüberblick

Dieses Repository enthält die vollständige Windows-Demo des Snackautomaten:

- Flutter-Oberfläche mit Kaufsession, Admin und integrierter Präsentation
- 3D-Automatenfront als GLB, gerendert in Babylon.js über das lokale Paket `power3d`
- lokale SQLite-Datenbank für Produkte, Slots, Münzen und Transaktionen

Blender wird zur Laufzeit **nicht** benötigt. Modellpflege und Export erfolgen außerhalb des Repos; in der App wird nur das fertige GLB geladen.

---

## Was die App kann

| Bereich | Beschreibung |
| --- | --- |
| 3D-Landing | Automaten-GLB in Babylon/Power3D, Kamera-Presets, Material-Styles |
| Kauf-Session | Phasen `ready → paymentInProgress → dispensing → thankYou` (+ `outOfService`) |
| Slot-Eingabe | Reihen A–D Spalten 1–10; E–F Dual-Breite (UI F1–F5); Commit nach ~3 s |
| Dispense | Elevator → Spirale → Fall → PUSH-Blink → Klappe (~5600 ms) |
| HUD-OLED | Session-Phasen als DynamicTexture auf `UI_HUD_Screen` |
| Bedienung | Sidebar am 3D-Screen + 2D-Fallback `VendingMachineScreen` |
| Admin | Produkte, Slots, Refill, Münzkassette, Asset-Import |
| Präsentation | 14 Folien in der App (`lib/features_snack/presentation/`) |
| Lager & Geld | Bestand, Wechselgeld (`ChangeCalculator`), Transaktionsprotokoll |

---

## Architektur

```text
┌─────────────────────────────────────────────────────────────┐
│  Flutter App (Windows)                                      │
│  Riverpod Session · Admin · Sidebar · DigitalDisplay        │
│  · Präsentation (presentation/*)                            │
│                                                             │
│    ├── SQLite (sqflite / FFI)                               │
│    │     Produkte · Slots · Münzen · Transaktionen          │
│    │                                                        │
│    └── Power3D (Babylon.js in flutter_inappwebview)         │
│          ├── GLB: vending_machine_front.glb                 │
│          ├── Dispense: Elevator → Spirale → Fall            │
│          └── HUD-OLED: DynamicTexture auf UI_HUD_Screen     │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ einmaliger Export (kein Live-HTTP)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Blender (außerhalb des Repos)                              │
│  Modellpflege + GLB-Export → assets/models/…                │
└─────────────────────────────────────────────────────────────┘
```

**Einstieg im Code:** [`lib/main.dart`](lib/main.dart) → SQLite + `Power3dBootstrap.ensureReady()` → `VendingMachine3DLandingScreen`.

Ausführliche Architektur, Naming und IST/SOLL: [`assets/install/Control.md`](assets/install/Control.md).

---

## Tech-Stack

| Schicht | Technologie | Einsatz |
| --- | --- | --- |
| UI / State | Flutter, Riverpod | Landing, Sidebar, Admin, Session, Folien |
| 3D | `power3d`, `flutter_inappwebview` | GLB, Dispense, Kamera, Materialien, HUD |
| DB | `sqflite` (+ `sqflite_common_ffi` Desktop) | Katalog, Lager, Münzen, Transaktionen |
| Modelle | Freezed, `json_serializable` | Domain-Objekte |
| Assets | `archive`, `path_provider`, `file_picker` | Power3D-ZIP, Admin-Uploads |
| Präsentation | Flutter-Folien | Diagramme unter `assets/presentation/` |

Vollständige Paketliste: [`assets/install/Dependencies.md`](assets/install/Dependencies.md).

---

## Voraussetzungen

### Pflicht (Windows-Desktop-Demo)

| Komponente | Warum | Hinweis |
| --- | --- | --- |
| Windows 10/11 (64-bit) | Primäre Zielplattform | Demo und 3D-Viewer sind darauf ausgelegt |
| [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) `^3.11.0` | App-Framework | `flutter --version` prüfen |
| [Visual Studio](https://visualstudio.microsoft.com/) mit **Desktop development with C++** | Windows-Desktop-Build | MSVC, Windows SDK, CMake |
| [Edge WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) | Host für Babylon/Power3D | oft schon installiert; sonst Evergreen Runtime |
| Git | Repo klonen | optional, wenn du das ZIP nutzt |
| ausreichend RAM / SSD | GLB ~85 MB | Erstload kann einige Sekunden dauern |

### Schnellcheck der Toolchain

In PowerShell oder CMD:

```bash
flutter --version
flutter doctor -v
```

Wichtig für dieses Projekt:

- Flutter ist installiert und im `PATH`
- Windows-Toolchain ist ok (`Visual Studio` / Desktop C++)
- Kein harter Fehler bei WebView2 / Windows Desktop

Wenn `flutter doctor` Windows-Desktop als fehlend meldet, zuerst Visual Studio mit der C++-Desktop-Workload nachinstallieren und erneut prüfen.

---

## Installation (Windows)

### 1. Repository holen

```bash
git clone <REPO-URL>
cd 3d_model
```

Oder das Projekt als ZIP entpacken und in den Ordner wechseln.

> **Hinweis:** Das GLB unter `assets/models/` ist groß (~85 MB). Beim Klonen ggf. LFS/lange Downloads abwarten, bis die Datei vollständig vorhanden ist.

### 2. Flutter-Abhängigkeiten installieren

Im Projektroot:

```bash
flutter pub get
```

Das zieht die Pub-Pakete und verknüpft das lokale Path-Paket `packages/power3d`.

### 3. Windows-Desktop aktivieren (falls nötig)

```bash
flutter config --enable-windows-desktop
flutter devices
```

Unter `flutter devices` sollte ein Eintrag wie `Windows (desktop)` erscheinen.

### 4. WebView2 prüfen

Ohne WebView2 startet der 3D-Viewer nicht zuverlässig.

- Runtime: [Microsoft Edge WebView2](https://developer.microsoft.com/microsoft-edge/webview2/)
- Danach ggf. Terminal neu öffnen und App erneut starten

### 5. (Optional) Sauberer Neuaufbau vor dem ersten Start

Nur nötig bei kaputtem Build-Stand oder nach abgebrochenen Cleanups:

```bash
flutter clean
flutter pub get
```

---

## App starten

### Debug (Entwicklung)

```bash
flutter run -d windows
```

Alternativ mit Gerätewahl:

```bash
flutter devices
flutter run -d windows
```

### Was beim ersten Start passiert

1. Power3D-Assets werden aus `packages/power3d/assets/power3d_assets.zip` nach Application Support entpackt  
2. Das GLB wird lokal kopiert und per HTTP an Babylon gereicht (`http://127.0.0.1:<port>/…`, kein `file://`)  
3. `ensureVendingPresentation` und `stabilizeVendingShelf` richten Szene und Regale aus  
4. SQLite legt `snackautomat.db` an und seedet den Katalog aus `assets/products/catalog.json`

In der Konsole siehst du u. a.:

- `Power3dBootstrap: Assets bereit unter …`
- `Power3DAssetManager: Model HTTP server on 127.0.0.1:…`
- `[JS] Meshes loaded: Array(1072)` (oder ähnlich)
- `syncVendingStock: … Slots belegt`

### Hot Reload / Restart

Während `flutter run`:

| Taste | Wirkung |
| --- | --- |
| `r` | Hot Reload |
| `R` | Hot Restart |
| `q` | App und `flutter run` beenden |

Nach größeren Änderungen an nativem Code, Assets oder Plugin-Verknüpfungen lieber voll neu starten (`q`, dann erneut `flutter run -d windows`).

---

## Release-Build

```bash
flutter build windows --release
```

**Ausgabe:**

```text
build/windows/x64/runner/Release/snackautomat_yakup_leandro.exe
```

Den kompletten `Release/`-Ordner weitergeben (DLL-Abhängigkeiten liegen daneben). Nur die `.exe` allein reicht nicht.

Optional danach Debug-Zwischenstände aufräumen:

```bash
flutter clean
```

> `flutter clean` löscht `build/`. Den Release-Ordner vorher kopieren, wenn du ihn behalten willst.

---

## Nach dem ersten Start

### Typische Runtime-Pfade (Windows)

| Was | Ungefährer Ort |
| --- | --- |
| Power3D-Assets | `%APPDATA%\…\power3d_assets\` |
| GLB-Kopie für den Viewer | `…\power3d_assets\models\vending_machine_front.glb` |
| SQLite | plattformabhängig über `getDatabasesPath()` / Debug oft unter `.dart_tool\…` |
| Admin-Uploads | Documents → `product_assets/`, `coin_assets/` |
| Präsentations-Overlays | Application Support → `presentation_overlays_v1.json` |

Details: [`assets/install/Paths.md`](assets/install/Paths.md).

### PIN / Admin / Präsentation

Admin- und Präsentationszugang sind PIN-geschützt. Die Konstante liegt in:

[`lib/features_snack/services/admin_access.dart`](lib/features_snack/services/admin_access.dart)

Der PIN-Wert steht bewusst nur im Code, nicht in der öffentlichen Doku.

---

## Bedienung (Kurz)

| Aktion | So geht’s |
| --- | --- |
| Produkt wählen | Slot-Code tippen (z. B. `A3`); nach kurzer Pause Commit |
| Bezahlen | Münzen einwerfen, bis der Preis erreicht ist |
| Ausgabe | Dispense-Animation beobachten, danach Klappe / Entnahme |
| Kamera | Presets z. B. `front`, `buy`, `dispense` |
| Material | Default `blender_dark` |
| Admin | PIN-Einstieg → Produkte, Slots, Refill, Münzen |
| Folien | PIN-Einstieg Präsentation in der App |

Live-Demo-Ablauf: [`assets/install/Presentation.md`](assets/install/Presentation.md) §5.

---

## Repository-Struktur

```text
3d_model/
├── README.md                      ← diese Datei
├── pubspec.yaml                   ← App-Metadaten & Assets
├── analysis_options.yaml
├── lib/
│   ├── main.dart                  ← Entry
│   └── features_snack/
│       ├── constants/
│       ├── models/
│       ├── providers/             ← Session, Kauf, Wechselgeld
│       ├── repositories/          ← SQLite + Migrationen
│       ├── services/              ← Bootstrap, Stock, Assets, Parser
│       ├── presentation/          ← In-App-Folien
│       ├── screens/
│       │   ├── vending_machine/   ← 3D-Landing + Controls + 2D
│       │   └── admin/
│       └── widgets/
├── packages/power3d/              ← Babylon-Viewer & Dispense-API
│   ├── assets/power3d_assets.zip
│   └── lib/src/controller/
├── assets/
│   ├── install/                   ← ausführliche Markdown-Doku
│   │   ├── Root.md
│   │   ├── Control.md
│   │   ├── Dependencies.md
│   │   ├── Paths.md
│   │   └── Presentation.md
│   ├── models/vending_machine_front.glb
│   ├── products/                  ← catalog.json + 47 Slugs
│   └── presentation/              ← diagrams, brand, status
└── windows/                       ← Desktop-Runner
```

Datei→Rolle und Datenfluss: [`assets/install/Root.md`](assets/install/Root.md).

---

## Kaufablauf & Mesh-Naming

### Kaufablauf

```text
ready
  → Slot tippen (A–F)
  → paymentInProgress (Münzen bis Preis)
  → dispensing (ChangeCalculator + DB + 3D-Animation)
  → Klappe öffnen / entnehmen
  → thankYou → ready
```

Parallel:

- `placedProductsProvider` → `syncVendingStock` (sichtbare Produkte im GLB)
- Session-Phase → `updateVendingHudOled` (3D) und `DigitalDisplay` (2D)

### Mesh-Naming (Kurz)

| Zweck | Pattern / Beispiel |
| --- | --- |
| Produkt-Stack | `Product_A01_s00` |
| Spirale | `Motor_A1_Spiral` |
| Aufzug | `Elevator_WideBasket*` |
| Klappe | `Vending_DeliveryFlap_Door` |
| HUD | `UI_HUD_Screen` |
| Keypad | `KP_*` (visuell; Raycast geplant) |

Vollständiger Objektkatalog: [`assets/install/Control.md`](assets/install/Control.md) §6.

---

## Dokumentation

| Datei | Inhalt |
| --- | --- |
| [`assets/install/Root.md`](assets/install/Root.md) | Verzeichnisbaum, Screens, Services, Domäne |
| [`assets/install/Control.md`](assets/install/Control.md) | Architektur, Phasen, Dispense, Naming, IST/SOLL |
| [`assets/install/Dependencies.md`](assets/install/Dependencies.md) | Abhängigkeiten, Setup, Troubleshooting |
| [`assets/install/Paths.md`](assets/install/Paths.md) | Bundle-, Support- und Documents-Pfade, Mesh↔Slot |
| [`assets/install/Presentation.md`](assets/install/Presentation.md) | Folien, Live-Demo, Learnings, Checkliste |

---

## Entwicklung

```bash
# Codegen nach Freezed-/JSON-Änderungen
dart run build_runner build --delete-conflicting-outputs

# Abhängigkeiten aktualisieren (mit Vorsicht)
flutter pub outdated
```

**Wichtige Einstiege im Code:**

| Thema | Datei |
| --- | --- |
| App-Start | [`lib/main.dart`](lib/main.dart) |
| 3D-Landing | `lib/features_snack/screens/vending_machine/vending_machine_3d_landing_screen.dart` |
| Session / Kauf | `lib/features_snack/providers/provider.dart` |
| Power3D-Bootstrap | `lib/features_snack/services/power3d_bootstrap.dart` |
| Dispense / HUD API | `packages/power3d/lib/src/controller/projection_extension.dart` |
| Kamera-Presets | `packages/power3d/lib/src/controller/view_extension.dart` |

---

## Troubleshooting

| Symptom | Ursache / Fix |
| --- | --- |
| `flutter devices` zeigt kein Windows | Desktop-Support aktivieren; Visual Studio C++-Workload prüfen |
| Build bricht mit C1083 / fehlenden Plugin-Dateien ab | `flutter clean` → `flutter pub get` → erneut bauen (oft nach gelöschtem `ephemeral`) |
| Leerer oder blockierter 3D-Viewer | Nur **eine** Viewer-Instanz; App komplett beenden und neu starten |
| WebView-Fehler / schwarzer Viewer | Edge WebView2 Runtime installieren |
| Produkte verrutscht / Spiralen orbitieren | Full Restart; Bake-Pose unter `__root__` nicht zerstören (`stabilizeVendingShelf`) |
| Langer Erststart | normal wegen ~85 MB GLB — einmal warm laden lassen |
| „Lost connection to device“ | App/WebView beendet; `flutter run -d windows` neu starten |
| Kein Stock / leere Slots | Admin → Refill; Katalog-Seed prüfen |
| Hot Reload hilft nicht | `R` (Hot Restart) oder voller Neustart nach Asset-/Native-Änderungen |

Ausführlicher: [`assets/install/Dependencies.md`](assets/install/Dependencies.md) §9–10.

### Empfohlene Reparatur-Sequenz

```bash
flutter clean
flutter pub get
flutter run -d windows
```

---

## Lizenz / Status

Privates Projekt / Studien- bzw. Demo-Arbeit von **Yakup & Leandro**.

Aktuell liegt kein separates `LICENSE`-File im Repo. Vor einer öffentlichen GitHub-Veröffentlichung Lizenz und Remote-URL ergänzen.
