import type { ReactNode } from "react";

const KEYWORDS = new Set([
  "abstract",
  "as",
  "assert",
  "async",
  "await",
  "break",
  "case",
  "catch",
  "class",
  "const",
  "continue",
  "default",
  "do",
  "dynamic",
  "else",
  "enum",
  "export",
  "extends",
  "extension",
  "external",
  "factory",
  "false",
  "final",
  "finally",
  "for",
  "get",
  "if",
  "implements",
  "import",
  "in",
  "is",
  "late",
  "mixin",
  "new",
  "null",
  "on",
  "operator",
  "part",
  "required",
  "rethrow",
  "return",
  "set",
  "show",
  "static",
  "super",
  "switch",
  "this",
  "throw",
  "true",
  "try",
  "typedef",
  "var",
  "void",
  "while",
  "with",
  "yield",
]);

const TYPES = new Set([
  "String",
  "int",
  "double",
  "bool",
  "List",
  "Map",
  "Set",
  "Future",
  "Duration",
  "Power3DController",
  "Power3D",
  "PlacedProduct",
  "VendingMachinePhase",
  "VendingMachine3DLandingScreen",
]);

const IMPORTANT = new Set([
  "fromAsset",
  "applyVendingCameraView",
  "syncVendingStock",
  "dispenseItem",
  "setDeliveryFlapOpen",
  "dispenseAnimationHandler",
  "_evalJs",
  "ensureProjectionHelpers",
  "stockBySlotFromPlaced",
  "decreaseStockAfterPurchase",
  "jsonEncode",
  "unawaited",
  "_onModelLoaded",
  "modelAsset",
  "copyWith",
]);

type Kind = "plain" | "keyword" | "type" | "fn" | "string" | "comment" | "number" | "important";

/** Dart Dark+-angelehntes Highlighting für Präsentationsfolien. */
export function highlightDart(source: string): ReactNode[] {
  const out: ReactNode[] = [];
  let i = 0;
  let key = 0;

  const push = (text: string, kind: Kind) => {
    if (!text) return;
    out.push(
      <span key={key++} className={`tok tok-${kind}`}>
        {text}
      </span>,
    );
  };

  while (i < source.length) {
    if (source.startsWith("//", i)) {
      const end = source.indexOf("\n", i);
      const slice = end === -1 ? source.slice(i) : source.slice(i, end);
      push(slice, "comment");
      i += slice.length;
      continue;
    }

    if (source[i] === "'" || source[i] === '"') {
      const quote = source[i]!;
      let j = i + 1;
      while (j < source.length) {
        if (source[j] === "\\") {
          j += 2;
          continue;
        }
        if (source[j] === quote) {
          j += 1;
          break;
        }
        j += 1;
      }
      push(source.slice(i, j), "string");
      i = j;
      continue;
    }

    if (/[0-9]/.test(source[i]!) && (i === 0 || !/[A-Za-z_]/.test(source[i - 1]!))) {
      let j = i;
      while (j < source.length && /[0-9.]/.test(source[j]!)) j += 1;
      push(source.slice(i, j), "number");
      i = j;
      continue;
    }

    if (/[A-Za-z_]/.test(source[i]!)) {
      let j = i;
      while (j < source.length && /[A-Za-z0-9_]/.test(source[j]!)) j += 1;
      const word = source.slice(i, j);
      const rest = source.slice(j);
      const ws = rest.match(/^\s*/)?.[0]?.length ?? 0;
      const next = rest[ws];

      let kind: Kind = "plain";
      if (KEYWORDS.has(word)) kind = "keyword";
      else if (IMPORTANT.has(word)) kind = "important";
      else if (TYPES.has(word) || /^[A-Z]/.test(word)) kind = "type";
      else if (next === "(") kind = "fn";

      push(word, kind);
      i = j;
      continue;
    }

    push(source[i]!, "plain");
    i += 1;
  }

  return out;
}
