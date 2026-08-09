# Presentation.md – Folien-Outline, Demo-Skript & Learnings

Präsentationsleitfaden für **Snackautomat Yakup & Leandro** (`3d_model`).

**Stand:** August 2026 · Master **`nur noch exportiertes GLB im Repo`** · Standalone Flutter + Power3D/Babylon

**Begleitdocs:** [`Control.md`](Control.md) · [`Dependencies.md`](Dependencies.md) · [`Root.md`](Root.md) · [`Paths.md`](Paths.md)

---

## 1. Projekt in einem Satz

Interaktive Flutter-App eines Snack-/Getränkeautomaten mit realistischer **3D-Front** (Blender → GLB → Power3D/Babylon), **voller Dispense-Sequenz** (Aufzug, Spirale, Fall, Klappe), **HUD-OLED-Sync** und **Kauf-/Admin-Logik** in SQLite — **standalone**, ohne Live-Blender-Bridge.

| | |
| --- | --- |
| Team | Yakup & Leandro |
| App-Name | `snackautomat_yakup_leandro` |
| Primär-Demo | Windows Desktop |
| Master-Blend | `nur noch exportiertes GLB im Repo` |
| Doku | `install/` (+ PDFs) |

![Maschine mit Keypad](previews/machine_kp_design.png)

---

## 2. Drei Präsentations-Kanäle

| Kanal | Pfad | Start |
| --- | --- | --- |
| **In-App-Folien** | `lib/features_snack/presentation/` | `openPresentationArea(context)` in `presentation_access.dart` (PIN wie Admin, siehe `admin_access.dart`) |
| **Next.js-Website** | `page/` | `cd page && npm run dev` → http://localhost:3000 |
| **Markdown/PDF-Doku** | `install/Presentation.md` | Dieses Dokument + `python install/generate_pdf.py` |

```mermaid
flowchart LR
  App[Flutter_App] --> Slides[kPresentationSlides]
  Slides --> Diagrams[assets_presentation_diagrams]
  Slides --> Brand[assets_presentation_brand]
  App --> Overlays[presentation_overlays_v1.json]
  Web[page_Next.js] --> SameStory[Gleiche_Story_14_Folien]
  Docs[install_previews] --> PNG[QA_Screenshots]
```

---

## 3. In-App-Folien (`kPresentationSlides`, 14 Stück)

Quelle: `lib/features_snack/presentation/slides.dart` · Dauer-Ziel: ~5–6 Min (`kPresentationTotal`).

| # | id | Typ | Titel / Kern | Bild (Bundle) |
| --- | --- | --- | --- | --- |
| 1 | `title` | Titel | Snackautomat 3D | Brand-Emblem |
| 2 | `goal` | Explain | Mesh ↔ App | `diagram_flutter_3d.png` |
| 3 | `zones` | Diagram | Zonen am Automaten | `diagram_zones.png` |
| 4 | `naming` | Diagram | Objekt-Prefixes | `diagram_naming.png` |
| 5 | `slots` | Diagram | Slot-Code A1–F10 | `diagram_slots.png` |
| 6 | `domain` | Diagram | Product ≠ Slot | `diagram_domain.png` |
| 7 | `load` | Code | GLB einbinden | — |
| 8 | `bridge` | Code | Dart → JS (`setDeliveryFlapOpen`) | — |
| 9 | `camera` | Code | Kamera-Presets | — |
| 10 | `stock` | Code | `syncVendingStock` | — |
| 11 | `dispense-session` | Code | Session → Handler | — |
| 12 | `dispense-3d` | Code | `dispenseItem` + Flap | — |
| 13 | `phases` | Flow | Phasen-Flow | — |
| 14 | `ist-soll` | Status | IST vs SOLL | — |

**Weitere Bundle-Diagramme** (optional für Beamer / Architektur-Folie):

| Datei | Thema |
| --- | --- |
| `assets/presentation/diagrams/diagram_architecture.png` | Architektur |
| `assets/presentation/diagrams/diagram_phases.png` | Session-Phasen |
| `assets/presentation/diagrams/diagram_pipeline.png` | Blender → GLB → App |

In-App referenzierte Diagramme liegen unter `assets/presentation/diagrams/` (8 PNGs). QA-Screenshots der 3D-Komponenten: `install/previews/` (14 PNGs).

![Panel Flush Check](previews/panel_flush_check.png)

---

## 4. Vorgeschlagene Beamer-Folienstruktur (~10–12 Folien)

| # | Folie | Kernbotschaft | Quelle |
| --- | --- | --- | --- |
| 1 | Titel | Snackautomat 3D – Flutter + Blender | — |
| 2 | Problem / Ziel | Vom 2D-Automaten zur glaubwürdigen 3D-Bedienfront | — |
| 3 | Architektur | Standalone: Flutter ↔ Power3D ↔ GLB ↔ SQLite; MCP nur Dev | Control §1 |
| 4 | Domain & Phasen | Product ≠ Slot; ready→pay→dispense→thankYou; HUD spiegelt Phasen | Control §2–3 |
| 5 | 3D-Tour Control Panel | Shell-PBR, KP, ePort, CoinMod, CoinReturn, Flap, Elevator | Control §6 + PNGs |
| 6 | Live-Demo Kauf | Slot → Münzen → Elevator/Spirale/Fall → Flap | Demo-Skript §5 |
| 7 | Admin & Lager | Produkte, Slots, Refill, Münzkassette | Root §2 |
| 8 | Pipeline | `entferntes Blender-Archivfinal_v004` → Export → GLB (~85 MB) → App | Control §7 · Paths |
| 9 | **Herausforderungen & Learnings** | Bake/Parent, Spirale, Elevator, Babylon-Materials | §6 |
| 10 | IST vs SOLL | Dispense+HUD IST; Mesh-Keypad / ePort-Live SOLL | Control §4 |
| 11 | Ausblick | Raycast-Keypad, Live-ePort, Sound | — |
| 12 | Q&A | — | §7 |

Optional: Next.js-Folien unter `page/` oder In-App via `PresentationScreen`.

---

## 5. Demo-Skript (Live)

**Vorbereitung (5 min vorher)**

1. `flutter pub get` (falls frisch)
2. WebView2 prüfen
3. `flutter run -d windows`
4. Warten bis GLB geladen; Produkte sitzen in den Slots
5. Material `blender_dark`; Kamera `front` oder `buy`
6. Slot mit Stock + Wechselgeld in der Kassette

**Ablauf (~4–6 min)**

| Schritt | Aktion | Was ihr sagt |
| --- | --- | --- |
| 1 | Kamera `front` → `front3d` → `buy` | „Presets für Präsentation und Bedienung“ |
| 2 | Slot tippen (z. B. A3) | „Session → paymentInProgress; HUD folgt“ |
| 3 | Münzen bis Preis | „SQLite-Münzkassette + ChangeCalculator“ |
| 4 | Dispense beobachten | „Aufzug zur Reihe → Spirale → Produkt fällt → Klappe“ |
| 5 | Flap / Entnahme | „Mesh-Interaktion; PUSH blinkt nach Ausgabe“ |
| 6 | Kurz Admin | „Katalog, Slots, Refill — Betriebsseite“ |
| 7 | Optional 2D | „Gleiche Logik, andere UI-Schicht“ |
| 8 | Optional Folien | In-App `PresentationScreen` oder `page/` im Browser |

**Falls etwas hakt**

- Viewer blocked → App **vollständig** neu starten
- Produkte verrutscht → Full Restart (Shelf-Stabilize beim Load)
- Kein Stock → Admin Refill
- Dunkles Mesh → Material-Style wechseln

![Flap PUSH](previews/flap_push_check.png)

![HUD](previews/hud_frame_round.png)

---

## 6. Herausforderungen & Learnings (Pflichtfolie)

| Thema | Was passiert ist | Learnings |
| --- | --- | --- |
| **GLB-Bake + Parent** | `setParent(null)` entfernte `__root__`-Y-up → Produkte drifteten, Spiralen orbitierten | Bake-Pose unter `__root__` lassen; `stabilizeVendingShelf` |
| **Spiral-Drehachse** | `mesh.rotate()` um Ursprung = Schleudern um die Maschine | `rotateAround` um Coil-Mitte, jeden Frame von Home |
| **Elevator-Höhe** | Parent+Child gleichzeitig bewegt → doppelte Delta-Höhe | Nur `Elevator_WideBasket`-Wurzel animieren |
| **Produkt-Glow / Unsichtbar** | Emissive pro Frame addiert; nur PET ohne Label bewegt | Emissive einmal nullen; PET+Label+Cap als Einheit |
| **Shading / N-Gons** | Harte Kanten in Babylon | `v5_fix_shading_artifacts.py`; Runtime-Material-Styles |
| **CoinMod LED Curves** | Oversized Curves sprengen Viewer | Export-Filter schließt `CoinMod_LED*` aus |
| **Single WebView** | Zweite Instanz blockiert | `ProductModelViewerLock` |
| **Product vs Slot** | Katalog ≠ Belegung | Migration 010, `PlacedProduct` |
| **Standalone vs Bridge** | Alte Doku Port 8765 | Demo braucht kein Live-Blender |

**Ein Satz für die Folie:**  
„Der schwierige Teil war nicht das Mesh — sondern stabile Babylon-Runtime: Bake-Pose, Pivot/Parent und eine glaubwürdige Dispense-Sequenz.“

---

## 7. Screenshot- / PNG-Mapping (`install/previews/`)

| Folie / Moment | Datei |
| --- | --- |
| CoinMod Close-up | `install/previews/coinmod_preview.png` |
| Slot-Wells | `install/previews/coinmod_slots_fix.png` |
| Panel + Coin Return | `install/previews/panel_cr_design.png` |
| Panel Flush | `install/previews/panel_flush_check.png` |
| Keypad | `install/previews/machine_kp_design.png`, `install/previews/kp_keys_metal.png`, `install/previews/kp_plate_ref.png` |
| Delivery-Flap / PUSH | `install/previews/flap_kp_design.png`, `install/previews/flap_push_check.png`, `install/previews/flap_before.png` |
| HUD / Glas | `install/previews/hud_frame_round.png`, `install/previews/hud_screen_fix.png`, `install/previews/glass_screen_fix.png` |
| Label-Streifen | `install/previews/label_rows_bw.png` |

Tipp: 3–4 starke Bilder in Folien; Rest als Backup.

![CoinMod](previews/coinmod_preview.png)

![Panel Coin Return](previews/panel_cr_design.png)

![Keypad Keys](previews/kp_keys_metal.png)

---

## 8. Talking Points & mögliche Fragen

**Warum nicht Unity?**  
Flutter-App (Kauf/Admin/DB) war da. GLB + WebView hält einen Stack.

**Warum Babylon / power3d?**  
Lokale Assets, Kamera-/Material-/Dispense-API erweiterbar.

**Läuft Blender während der Demo?**  
Nein. Nur für Pflege und Export aus `nur noch exportiertes GLB im Repo` via `ehem. Blender-Skripte/v5_export_flutter_front_glb.py`.

**Was ist IST vs SOLL?**  
IST: Sidebar-Kauf, Stock-Sync, Elevator/Spirale/Fall, Flap, HUD-OLED, Admin.  
SOLL: Mesh-Hits auf `KP_*`, Live-ePort-Screen, Sound.

**Wie groß ist das Modell?**  
GLB ~85 MB — Demo-PC einmal warm laden.

**E/F Dual-Slots?**  
UI F1–F5 → physische Spalten 1,3,5,7,9; zwei Spiralen gleichzeitig.

**Wo liegen die Pfade?**  
Siehe [`Paths.md`](Paths.md) — Bundle vs. Application Support vs. Documents.

**Wo ist der Admin-/Präsentations-PIN definiert?**  
Konstante in `lib/features_snack/services/admin_access.dart` (Inhalt nicht in Doku — nur Code-Pfad).

---

## 9. Zeitbudget-Vorschlag

| Block | Dauer |
| --- | --- |
| Story + Architektur | 3–4 min |
| 3D-Tour | 2 min |
| Live-Kaufdemo (mit Dispense) | 4–5 min |
| Admin kurz | 1–2 min |
| Learnings + Ausblick | 2–3 min |
| Fragen | Rest |

---

## 10. Checkliste am Demo-Tag

- [ ] Windows-Build startet, GLB sichtbar, Produkte in den Slots
- [ ] Mindestens ein Slot mit Stock und bekanntem Preis
- [ ] Münzkassette hat Wechselgeld
- [ ] Kameras `front` / `buy` / `dispense` getestet
- [ ] Dispense: Aufzug + Spirale + Fall sichtbar
- [ ] Flap-Hover / PUSH-Blink funktioniert
- [ ] HUD folgt Phasen (optional zeigen)
- [ ] 2–3 PNGs aus `install/previews/` in Folien (falls Beamer ohne Repo)
- [ ] Backup: 2D-Screen falls WebView spinnt
- [ ] Learnings (Bake/Parent, Spirale, Elevator) parat

---

## 11. Verwandte Doku

- [`Control.md`](Control.md) — technische Tiefe  
- [`Dependencies.md`](Dependencies.md) — Setup & Plattformen  
- [`Root.md`](Root.md) — Dateibaum  
- [`Paths.md`](Paths.md) — Datei-Verknüpfung  

PDF regenerieren: `python install/generate_pdf.py`
