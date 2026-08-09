# Docs-Regen (Cursor SDK) — was ist das?

**regen** = optionaler **Doku-Auffrischer**. Ein Cursor-Agent (SDK) liest die Codebasis und aktualisiert:

- Root-`README.md`
- `install/*.md`
- danach PDFs via `python install/generate_pdf.py`

Es baut **nicht** die Flutter-App und ändert keine Kauf-/3D-Logik. Die Doku unter `install/` ist bereits manuell aktuell — `npm run regen` brauchst du nur, wenn du sie später automatisch neu erzeugen willst.

## Voraussetzungen

- Node.js **≥ 22.13**
- Python (für PDF-Generator / reportlab)
- Cursor API-Key (`crsr_…` / `key_…` / `cursor_…`)

### API-Key

Reihenfolge:

1. Env-Var `CURSOR_API_KEY` (Override)
2. Sonst Datei **`h:\Tools\Keys\CURSOR_API_KEY.txt`**
3. Optional: `CURSOR_API_KEY_FILE` auf einen anderen Pfad

Die Datei darf so aussehen (Label + Key in zwei Zeilen) — das Skript parst den Token:

```
Cursor api:
crsr_xxxxxxxx
```

Der Key wird **nicht** ins Repo geschrieben.

## Setup

```bash
cd install/regen
npm install
```

## Ausführen

```bash
cd install/regen
npm run regen
```

Bei Netzwerkfehlern versucht das Skript bis zu 3× erneut.

## PDFs manuell (ohne SDK / ohne Internet zur Cursor-API)

```bash
python install/generate_pdf.py
```

## Typische Fehler

| Meldung | Ursache |
| --- | --- |
| `Network request failed` | Kein Netzzugang zur Cursor-API, oder früher: Key inkl. Label-Zeile falsch gelesen |
| `Kein gültiger Cursor-API-Key` | Datei ohne `crsr_`/`key_`/`cursor_`-Token |
| `startup failed` nicht retryable | Auth/Config — Key im Dashboard prüfen |
