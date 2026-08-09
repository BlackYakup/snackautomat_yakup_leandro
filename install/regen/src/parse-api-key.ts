/** Extract a Cursor API key from env value or key-file contents (label lines OK). */
export function parseApiKey(raw: string): string {
  const text = raw.replace(/^\uFEFF/, "").trim();
  if (!text) {
    throw new Error("API-Key-Inhalt ist leer.");
  }

  const tokenRe = /\b((?:crsr_|key_|cursor_)[A-Za-z0-9_-]+)\b/;
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);

  for (const line of lines) {
    if (/^cursor\s*api\s*:?\s*$/i.test(line)) continue;
    const m = line.match(tokenRe);
    if (m) return m[1];
    const afterColon = line.includes(":")
      ? line.slice(line.indexOf(":") + 1).trim()
      : "";
    if (afterColon) {
      const m2 = afterColon.match(tokenRe);
      if (m2) return m2[1];
      if (/^(?:crsr_|key_|cursor_)/.test(afterColon)) return afterColon;
    }
    if (/^(?:crsr_|key_|cursor_)/.test(line)) return line;
  }

  const any = text.match(tokenRe);
  if (any) return any[1];

  throw new Error(
    "Kein gültiger Cursor-API-Key gefunden (erwartet Token mit Prefix crsr_ / key_ / cursor_).",
  );
}
