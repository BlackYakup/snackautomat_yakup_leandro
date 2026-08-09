# Snackautomat 3D – Präsentation

Klickbare Folien (~5–6 Min.) mit Zonen-/Slot-Diagrammen und **echten Dart-Code-Ausschnitten** zur 3D-Steuerung.

## Start

```bash
cd page
npm install
npm run dev
```

Browser: [http://localhost:3000](http://localhost:3000) (oder Port aus dem Terminal)

## Inhalt

1. Titel  
2. Mesh ↔ App  
3. Zonen  
4. Naming (`KP_*`, …)  
5. Slots A1–F10  
6. Domain  
7. **Code:** GLB laden (`Power3D.fromAsset`)  
8. **Code:** Dart → JS (`_evalJs` / Klappe)  
9. **Code:** Kamera-Presets  
10. **Code:** `syncVendingStock`  
11. **Code:** Session → Handler  
12. **Code:** `dispenseItem` + Flap  
13. Phasen  
14. IST / SOLL · Abschluss  

Quellen: `lib/features_snack/screens/vending_machine/vending_machine_3d_landing_screen.dart`, `providers/provider.dart`, `packages/power3d`.
