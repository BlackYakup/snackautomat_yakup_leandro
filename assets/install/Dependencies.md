# Dependencies.md – Plugins, Pakete & Plattformen

Dokumentation der tatsächlich installierten Abhängigkeiten und Laufzeit-Voraussetzungen für **snackautomat_yakup_leandro**.

**Stand:** August 2026 · App `1.0.0+1` · SDK `^3.11.0`

**Quellen:** `pubspec.yaml`, `pubspec.lock`, `packages/power3d/pubspec.yaml`, `lib/features_snack/services/power3d_bootstrap.dart`.

**Begleitdocs:** [`Root.md`](Root.md) · [`Control.md`](Control.md) · [`Paths.md`](Paths.md) · [`Presentation.md`](Presentation.md)

---

## 1. Überblick Schichten

| Schicht | Technologie | Zweck |
| --- | --- | --- |
| Flutter UI | Material + Riverpod | Landing, Sidebar, 2D-Fallback, Admin, HUD, Präsentation |
| 3D-Anzeige | `power3d` + `flutter_inappwebview` | GLB + Babylon (Dispense, Elevator, Spirale, Flap, HUD-OLED) |
| Persistenz | `sqflite` (+ `sqflite_common_ffi` Desktop) | Produkte, Slots, Münzen, Transaktionen |
| Modelle | Freezed / json_serializable | Domain-Objekte |
| Blender (Dev) | bpy / bmesh in Blender | Modellbau + GLB-Export **außerhalb** des Repos |

### Nicht im Projekt (Verwechslung mit Referenz-Repo)

- `blender_bridge_service` / HTTP-Port `8765`
- `model_viewer_plus`, `webview_flutter` (statt InAppWebView)
- separates Pub-Paket `http` als Kauf-Bridge
- Unity / Three.js als App-Engine

---

## 2. Direkte Abhängigkeiten (App `pubspec.yaml`)

Versionen aus `pubspec.lock` (aufgelöst). Constraint in Klammern.

### 2.1 Runtime (`dependencies`)

| Paket | Version (lock) | Constraint | Wofür | Wo genutzt |
| --- | --- | --- | --- | --- |
| `flutter` | SDK | sdk | UI-Framework | gesamte App |
| `power3d` | 2.3.1 | path: `packages/power3d` | Babylon-Viewer, Dispense-API | Landing-Screen, `packages/power3d/lib/**` |
| `flutter_riverpod` | 3.3.2 | ^3.3.2 | Session-State, Repos | `providers/`, Screens |
| `flutter_inappwebview` | 6.1.5 | ^6.1.5 | WebView-Host für Babylon | power3d (transitiv + direkt) |
| `sqflite` | 2.4.3 | ^2.4.3 | SQLite (Mobile) | `db_creater.dart`, Repositories |
| `sqflite_common_ffi` | 2.4.2 | ^2.4.2 | SQLite FFI (Desktop) | `database_factory_config_io.dart` |
| `archive` | 4.0.9 | ^4.0.7 | ZIP entpacken | `power3d_bootstrap.dart` |
| `path_provider` | 2.1.6 | ^2.1.5 | OS-Verzeichnisse | Bootstrap, Asset-Storages, PresentationStore |
| `path` | 1.9.1 | ^1.9.1 | Pfad-Normalisierung | Asset-Storages, Bootstrap |
| `file_picker` | 8.3.7 | ^8.1.7 | Datei-Auswahl Admin | Admin-Panels (Produkt-/Münz-Import) |
| `freezed_annotation` | 3.1.0 | ^3.1.0 | Immutable-Modelle | `models/**` |
| `json_annotation` | 4.12.0 | ^4.12.0 | JSON-Serialisierung | `models/**`, `catalog.json` |
| `cupertino_icons` | 1.0.9 | ^1.0.8 | Icons | UI |
| `desktop_drop` | — | ^0.7.1 | Drag & Drop Desktop | Admin / Editor |
| `pasteboard` | — | ^0.5.0 | Zwischenablage | Admin / Editor |

### 2.2 Entwicklung (`dev_dependencies`)

| Paket | Version (lock) | Constraint | Wofür | Wo genutzt |
| --- | --- | --- | --- | --- |
| `build_runner` | 2.15.1 | ^2.15.1 | Code-Generierung | `*.g.dart`, `*.freezed.dart` |
| `freezed` | 3.2.5 | ^3.2.5 | Freezed-Codegen | `models/**` |
| `json_serializable` | 6.14.0 | ^6.14.0 | JSON-Codegen | `models/**` |
| `flutter_lints` | 6.0.0 | ^6.0.0 | Lint-Regeln | `analysis_options.yaml` |

**SDK:** `environment.sdk: ^3.11.0`

---

## 3. Path-Paket `power3d` (`packages/power3d`)

```yaml
power3d:
  path: packages/power3d   # Version 2.3.1
```

| Paket | Version (lock) | Wofür | Wo genutzt |
| --- | --- | --- | --- |
| `flutter` | SDK | Widget-Framework | `lib/power3d.dart`, Widgets |
| `flutter_inappwebview` | 6.1.5 | Babylon in WebView | Viewer-Host |
| `path` | 1.9.1 | Pfade | `asset_manager.dart` |
| `path_provider` | 2.1.6 | Support-Verzeichnis | Asset-Serve |
| `archive` | 4.0.9 | ZIP (intern) | Asset-Bootstrap |
| `meta` | 1.17.0 | Annotations | power3d lib |

**Assets:** `packages/power3d/assets/power3d_assets.zip` → entpackt nach Application Support.

### Kern-Extensions

| Datei | API |
| --- | --- |
| `projection_extension.dart` | Dispense, Elevator, Flap, Stock, HUD |
| `view_extension.dart` | Kamera-Presets |
| `material_extension.dart` | Material-Styles |
| `asset_manager.dart` | Local-HTTP-Serve |

---

## 4. Flutter – 3D Viewer / WebView (Detail)

### 4.1 Einbindung GLB

```yaml
assets:
  - assets/models/vending_machine_front.glb
  - assets/products/catalog.json
  - assets/products/<slug>/
  - assets/presentation/diagrams/
  - assets/presentation/brand/
  - assets/presentation/status/
```

Landing: `VendingMachine3DLandingScreen.modelAsset` = `assets/models/vending_machine_front.glb`.

### 4.2 Bootstrap-Flow

Logik: `lib/features_snack/services/power3d_bootstrap.dart`

```text
packages/power3d/assets/power3d_assets.zip
  → archive entpacken
  → {ApplicationSupport}/power3d_assets/
  → index.html + babylon/babylon.js vorhanden?
```

### 4.3 WebView-Einschränkung

| Thema | Detail |
| --- | --- |
| Host | Power3D in `flutter_inappwebview` |
| Constraint | Nur **eine** aktive Viewer-Instanz — `ProductModelViewerLock` |
| Windows | WebView2 Runtime erforderlich |
| Großes GLB | Serve über `http://127.0.0.1:<port>/…` (kein `file://`) |

---

## 5. State, DB, Migrationen

| Thema | Detail |
| --- | --- |
| ORM | sqflite direkt (kein Drift) |
| Migrations | `migration_001_…` bis `migration_010_product_slot_normalization.dart` |
| Desktop | `sqflite_common_ffi` + `database_factory_config_io.dart` |
| Seed | `assets/products/catalog.json` → SQLite beim Start |

---

## 6. Plattform-Spezifika

### 6.1 Windows (Primär)

| Thema | Hinweis |
| --- | --- |
| WebView2 | Microsoft Edge WebView2 Runtime nötig |
| Build | `flutter run -d windows` |
| FFI | `sqflite_common_ffi` |
| GLB | ~85 MB — Erstload einmal „warm“ laden |

### 6.2 Android / iOS / macOS / Linux / Web

Runner unter `windows/` aktiv. Produktionsfokus der 3D-Demo: **Windows**.

---

## 7. Blender / Python (Modell-Toolchain, Dev only)

Kein `pip install` für die App-Laufzeit. Skripte laufen in Blender **außerhalb** des Repos:

| Modul | Zweck |
| --- | --- |
| `bpy` / `bmesh` | Geometrie, Materialien, Export |
| `mathutils` | Matrizen / Vektoren |

| Artefakt | Rolle |
| --- | --- |
| Master-Blend (extern) | Szene |
| `v5_export_flutter_front_glb.py` | Export → Flutter-GLB |
| `v5_fix_shading_normals.py` | Shading-Fixes |

---

## 8. Doku- & Tool-Abhängigkeiten (nicht Flutter)

| Tool | Zweck | Pfad |
| --- | --- | --- |
| Markdown-Doku | Projektbeschreibung | `assets/install/*.md` |

---

## 9. Installations-Checkliste (Entwickler)

1. Flutter SDK passend zu `^3.11.0`
2. `flutter pub get`
3. Windows: WebView2 Runtime
4. Bei Modelländerungen: GLB neu exportieren und unter `assets/models/` ersetzen
5. `flutter run -d windows`
6. Erster Start: Power3D-Assets entpacken; GLB laden; Presentation + Shelf-Stabilize

---

## 10. Troubleshooting

| Symptom | Check |
| --- | --- |
| „Viewer blocked“ / leerer 3D | Zweite Instanz? App neu starten |
| Produkte verrutscht / Spiralen orbitieren | Full Restart; `stabilizeVendingShelf` (nie Parent von Product/Spiral entfernen) |
| Aufzug zu hoch | Nur WideBasket-Wurzel bewegen; Delta aus Produkt-Unterkante |
| Produkte leuchten | Emissive nicht pro Frame addieren; Material-Style `blender_dark` |
| Schwarzes / falsches Shading | Style + Shading-Fix-Skript |
| Fehlende CoinMod/KP/ePort | Export-`want()`; GLB neu |
| DB Desktop | FFI-Init |
| Langer Erstload | GLB-Größe; Statuszeile |
| Build C1083 / kaputte Plugin-Symlinks | `flutter clean` → `flutter pub get` → neu bauen |

---

## 11. SOLL / spätere Deps (noch nicht nötig)

| Thema | Mögliche Ergänzung |
| --- | --- |
| Mesh-Keypad-Raycast | power3d Hit-Test → Session-API |
| ePort Live-Screen | Texture-Upload / Overlay |
| Optional Training-Bridge | HTTP nur wenn Live-Blender-Dispense gewünscht |
| Sound | Audio bei Dispense / Flap |

---

## 12. Verwandte Doku

| Datei | Inhalt |
| --- | --- |
| [`Control.md`](Control.md) | Architektur, Dispense, Objekte |
| [`Root.md`](Root.md) | Dateibaum |
| [`Paths.md`](Paths.md) | Pfade & Asset-Verknüpfung |
| [`Presentation.md`](Presentation.md) | Demo & Folien |
