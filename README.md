# Snackautomat Yakup & Leandro

Interaktive Flutter-App eines Snack-/Getränkeautomaten mit realistischer **3D-Front** (Blender → GLB → Power3D/Babylon), voller **Dispense-Sequenz**, **HUD-OLED-Sync**, **Kauf-/Admin-Logik** in SQLite und **integrierter Präsentation** — **standalone**, ohne Live-Blender-Bridge.

| | |
| --- | --- |
| App-Paket | `snackautomat_yakup_leandro` `1.0.0+1` |
| SDK | Dart/Flutter `^3.11.0` |
| Primär-Demo | Windows Desktop |
| 3D-Viewer | lokales Path-Paket [`packages/power3d`](packages/power3d) `2.3.1` |
| Runtime-GLB | `assets/models/vending_machine_front.glb` (~85 MB) |

---

## Was die App kann

| Fähigkeit | Kurzbeschreibung |
| --- | --- |
| 3D-Landing | GLB `assets/models/vending_machine_front.glb` in Babylon/Power3D |
| Kauf-Session | Phasen `ready → paymentInProgress → dispensing → thankYou` (+ `outOfService`) |
| Slot-Eingabe | A–D 1–10; E–F Dual-Breite; Parser mit ~3 s Commit-Delay |
| Dispense | Elevator → Spirale → Fall → Flap (~5600 ms) |
| HUD-OLED | Session-Phasen → DynamicTexture auf `UI_HUD_Screen` |
| Sidebar / 2D | Bedienung am 3D-Screen + Fallback `VendingMachineScreen` |
| Admin | Produkte, Slots, Refill, Münzkassette, Asset-Import (PIN in `admin_access.dart`) |
| Präsentation | 14 Folien in der App (`lib/features_snack/presentation/`) + Next.js unter `page/` |
| Persistenz | SQLite `snackautomat.db` (Produkte, Slots, Münzen, Transaktionen; Migrationen 001–010) |
| Katalog | 47 Produkt-Slugs unter `assets/products/` |

![Keypad an Maschine](install/previews/machine_kp_design.png)

---

## Tech-Stack

| Schicht | Technologie | Wofür |
| --- | --- | --- |
| UI / State | Flutter + Riverpod | Landing, Sidebar, Admin, Session, Präsentation |
| 3D | power3d + flutter_inappwebview | GLB, Dispense, Kamera, Materialien, HUD |
| DB | sqflite (+ FFI Desktop) | Katalog, Lager, Münzen, Transaktionen |
| Modelle | Freezed / json_serializable | Domain-Objekte |
| Assets | archive + path_provider | Power3D-ZIP entpacken; Admin-Uploads in Documents |
| Präsentation | Flutter-Folien + Next.js | Diagramme unter `assets/presentation/` |

Details: [`install/Dependencies.md`](install/Dependencies.md) · Pfade: [`install/Paths.md`](install/Paths.md)

---

## Quickstart (Windows)

**Voraussetzungen**

1. Flutter SDK passend zu `^3.11.0`
2. **Microsoft Edge WebView2 Runtime** installiert
3. Optional für PDF-Doku: Python 3 + `reportlab` (wird bei Bedarf automatisch installiert)

**Start**

```bash
flutter pub get
flutter run -d windows
```

**Erster Start:** Power3D-Assets entpacken nach Application Support (`power3d_assets/`), GLB laden (einmal „warm“, ~85 MB), `ensureVendingPresentation` + `stabilizeVendingShelf`. SQLite legt `snackautomat.db` automatisch an.

**Präsentations-Website (optional)**

```bash
cd page
npm install
npm run dev
```

---

## Dokumentation (`install/`)

| Datei | Inhalt |
| --- | --- |
| [`install/Root.md`](install/Root.md) / PDF | Verzeichnisbaum, Datei→Rolle |
| [`install/Control.md`](install/Control.md) / PDF | Architektur, Naming, Dispense, IST/SOLL |
| [`install/Dependencies.md`](install/Dependencies.md) / PDF | Plugins/Pakete, Setup, Troubleshooting |
| [`install/Paths.md`](install/Paths.md) / PDF | Bundle-, Support- & Documents-Pfade, Asset-Flow |
| [`install/Presentation.md`](install/Presentation.md) / PDF | Folien, Demo-Skript, Learnings, Preview-Bilder |

PDFs erzeugen:

```bash
python install/generate_pdf.py
```

Doku später per Cursor SDK neu generieren: [`install/regen/`](install/regen/)

---

## Repo-Inhalt (bereinigt)

**Im Repo:** `lib/`, `packages/power3d/`, `assets/models/`, `assets/products/`, `assets/presentation/`, `windows/`, `pubspec.yaml`, `install/`, `test/`, `page/`

Blender-Master, Export-Skripte und Roh-Assets wurden aus dem Repo entfernt (Altlasten / Speicher). Die App läuft standalone über das exportierte GLB.

---

## Einstieg im Code

`lib/main.dart` → SQLite (`DbCreater`) + `Power3dBootstrap.ensureReady()` → `VendingMachine3DLandingScreen`.
