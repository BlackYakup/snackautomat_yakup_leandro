/**
 * One-shot: regenerate README + install/*.md from the live codebase via Cursor SDK,
 * then rebuild PDFs with install/generate_pdf.py.
 *
 * Was ist das?
 *   "regen" = Doku-Auffrischer. Ein lokaler Cursor-Agent liest die Codebase und
 *   aktualisiert install/*.md + README, danach PDFs. Die App selbst wird nicht gebaut.
 *
 * Auth: CURSOR_API_KEY env, else h:\Tools\Keys\CURSOR_API_KEY.txt
 *   (Datei darf Label-Zeilen wie "Cursor api:" enthalten — der echte Key wird geparst.)
 */
import { readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Agent, CursorAgentError } from "@cursor/sdk";
import { parseApiKey } from "./parse-api-key.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REGEN_ROOT = resolve(__dirname, "..");
const INSTALL_ROOT = resolve(REGEN_ROOT, "..");
const REPO_ROOT = resolve(INSTALL_ROOT, "..");
const DEFAULT_KEY_FILE = "h:\\Tools\\Keys\\CURSOR_API_KEY.txt";
const MAX_ATTEMPTS = 3;

function loadApiKey(): string {
  const fromEnv = process.env.CURSOR_API_KEY;
  if (fromEnv?.trim()) {
    const key = parseApiKey(fromEnv);
    console.log(`Auth: CURSOR_API_KEY (env), token ${key.slice(0, 8)}…`);
    return key;
  }
  const keyPath = process.env.CURSOR_API_KEY_FILE?.trim() || DEFAULT_KEY_FILE;
  if (!existsSync(keyPath)) {
    throw new Error(
      `Kein API-Key: setze CURSOR_API_KEY oder lege den Key unter ${DEFAULT_KEY_FILE} ab.`,
    );
  }
  const key = parseApiKey(readFileSync(keyPath, "utf8"));
  console.log(`Auth: ${keyPath} → token ${key.slice(0, 8)}…`);
  return key;
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

const PROMPT = `Aktualisiere die Projektdokumentation dieses Repos (Snackautomat Yakup & Leandro).

Ziele (nur Doku, KEINE App-Logik ändern):
1. Root-README.md — was die App kann, Tech-Stack, Quickstart Windows, Links auf install/
2. install/Root.md — aktueller Verzeichnisbaum, Datei→Rolle
3. install/Control.md — Architektur, Phasen, Dispense, Mesh-Naming, IST/SOLL
4. install/Dependencies.md — jedes Pub-/Path-Paket: Version, wofür, wo genutzt
5. install/Paths.md — Bundle-, ApplicationSupport- und Documents-Pfade, Mesh↔Slot, Asset-Flow
6. install/Presentation.md — Folien/Demo; Preview-Bilder aus install/previews/

Regeln:
- Sprache: Deutsch
- Kein gelöscht/-Ordner mehr im Repo (Blender-Archiv entfernt) — App nur über exportiertes GLB
- Bilder mit Markdown ![…](previews/…) einbinden wo sinnvoll
- Tabellen und ASCII-/Mermaid-Diagramme behalten/ergänzen
- Nach den Markdown-Updates: python install/generate_pdf.py ausführen
- Keine Secrets committen; Key-Pfade nur dokumentieren, nicht den Key-Inhalt

Arbeite im Repo-Root und speichere alle Dateien.`;

async function runOnce(apiKey: string) {
  return Agent.prompt(PROMPT, {
    apiKey,
    model: { id: "composer-2.5" },
    local: { cwd: REPO_ROOT },
  });
}

async function main(): Promise<void> {
  console.log("regen = Doku-Auffrischer via Cursor SDK (kein App-Build).");
  const apiKey = loadApiKey();
  console.log(`cwd: ${REPO_ROOT}`);

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    console.log(
      `Starte Agent.prompt (local) … Versuch ${attempt}/${MAX_ATTEMPTS}`,
    );
    try {
      const result = await runOnce(apiKey);

      console.log("status:", result.status);
      if (result.durationMs != null) {
        console.log("durationMs:", result.durationMs);
      }
      if (result.result) {
        console.log("--- assistant ---");
        console.log(result.result);
      }
      if (result.status === "error") {
        process.exitCode = 2;
        return;
      }
      if (result.status === "cancelled") {
        process.exitCode = 3;
        return;
      }
      return;
    } catch (err) {
      if (err instanceof CursorAgentError) {
        const retryable = err.isRetryable && attempt < MAX_ATTEMPTS;
        console.error(
          `startup failed: ${err.message} (retryable=${err.isRetryable})`,
        );
        if (retryable) {
          const waitMs = 1500 * attempt;
          console.error(`Warte ${waitMs}ms und versuche erneut …`);
          await sleep(waitMs);
          continue;
        }
        console.error(
          "Tipp: Key muss mit crsr_/key_/cursor_ beginnen (ohne Label-Zeile).",
        );
        console.error(
          "Tipp: Internet/VPN prüfen — SDK braucht Verbindung zu Cursor-Cloud.",
        );
        process.exitCode = 1;
        return;
      }
      throw err;
    }
  }
}

main();
