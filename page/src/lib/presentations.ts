import { SLIDES, type Slide } from "@/data/slides";
import { type OverlayDoc, uid } from "@/lib/overlays";

const LIBRARY_KEY = "sa-presentation-library-v1";
const LEGACY_OVERLAYS_KEY = "sa-presentation-overlays-v1";

export type StoredPresentation = {
  id: string;
  title: string;
  description: string;
  createdAt: number;
  updatedAt: number;
  archived: boolean;
  kind: "template" | "custom";
  slides: Slide[];
  overlays: OverlayDoc;
};

export type LibraryStore = {
  version: 1;
  items: StoredPresentation[];
};

export function createBlankDeck(title: string): Slide[] {
  return [
    {
      id: "title",
      kind: "title",
      title,
      subtitle: "Eigene Präsentation",
      meta: "Leer · bearbeitbar",
      speakHint: "",
    },
    {
      id: "s1",
      kind: "explain",
      kicker: "Inhalt",
      title: "Erste Folie",
      points: ["Hier Notizen ergänzen", "Elemente per Bearbeiten platzieren"],
      speakHint: "",
    },
    {
      id: "s2",
      kind: "explain",
      kicker: "Inhalt",
      title: "Zweite Folie",
      points: ["Weitere Punkte", "Bilder und Kästen hinzufügen"],
      speakHint: "",
    },
    {
      id: "end",
      kind: "closing",
      title: "Danke",
      lines: ["Fragen?"],
      speakHint: "",
    },
  ];
}

function cloneSlides(slides: Slide[]): Slide[] {
  return structuredClone(slides);
}

export function createPresentation(opts: {
  title: string;
  description?: string;
  from: "template" | "blank" | StoredPresentation;
}): StoredPresentation {
  const now = Date.now();
  let slides: Slide[];
  let overlays: OverlayDoc = {};
  let kind: StoredPresentation["kind"] = "custom";

  if (opts.from === "template") {
    slides = cloneSlides(SLIDES);
    kind = "template";
  } else if (opts.from === "blank") {
    slides = createBlankDeck(opts.title.trim() || "Neue Präsentation");
  } else {
    slides = cloneSlides(opts.from.slides);
    overlays = structuredClone(opts.from.overlays);
    kind = opts.from.kind;
  }

  return {
    id: uid("deck"),
    title: opts.title.trim() || "Neue Präsentation",
    description: opts.description?.trim() ?? "",
    createdAt: now,
    updatedAt: now,
    archived: false,
    kind,
    slides,
    overlays,
  };
}

function emptyStore(): LibraryStore {
  return { version: 1, items: [] };
}

function ensureDefault(store: LibraryStore): LibraryStore {
  if (store.items.length > 0) return store;

  let legacyOverlays: OverlayDoc = {};
  try {
    const raw = localStorage.getItem(LEGACY_OVERLAYS_KEY);
    if (raw) legacyOverlays = JSON.parse(raw) as OverlayDoc;
  } catch {
    /* ignore */
  }

  const now = Date.now();
  const starter: StoredPresentation = {
    id: "deck_snackautomat",
    title: "Snackautomat 3D",
    description: "Standardvorlage · Flutter, Zonen, Slots, Dart-API",
    createdAt: now,
    updatedAt: now,
    archived: false,
    kind: "template",
    slides: cloneSlides(SLIDES),
    overlays: legacyOverlays,
  };

  return { version: 1, items: [starter] };
}

export function loadLibrary(): LibraryStore {
  if (typeof window === "undefined") return emptyStore();
  try {
    const raw = localStorage.getItem(LIBRARY_KEY);
    if (!raw) return ensureDefault(emptyStore());
    const parsed = JSON.parse(raw) as LibraryStore;
    if (!parsed?.items || !Array.isArray(parsed.items)) return ensureDefault(emptyStore());
    return ensureDefault(parsed);
  } catch {
    return ensureDefault(emptyStore());
  }
}

export function saveLibrary(store: LibraryStore) {
  localStorage.setItem(LIBRARY_KEY, JSON.stringify(store));
}

export function upsertPresentation(store: LibraryStore, item: StoredPresentation): LibraryStore {
  const idx = store.items.findIndex((p) => p.id === item.id);
  const items = [...store.items];
  const next = { ...item, updatedAt: Date.now() };
  if (idx >= 0) items[idx] = next;
  else items.unshift(next);
  return { ...store, items };
}

export function setArchived(store: LibraryStore, id: string, archived: boolean): LibraryStore {
  return {
    ...store,
    items: store.items.map((p) =>
      p.id === id ? { ...p, archived, updatedAt: Date.now() } : p,
    ),
  };
}

export function renamePresentation(
  store: LibraryStore,
  id: string,
  title: string,
  description?: string,
): LibraryStore {
  return {
    ...store,
    items: store.items.map((p) =>
      p.id === id
        ? {
            ...p,
            title: title.trim() || p.title,
            description: description !== undefined ? description.trim() : p.description,
            updatedAt: Date.now(),
          }
        : p,
    ),
  };
}

export function deletePresentation(store: LibraryStore, id: string): LibraryStore {
  return { ...store, items: store.items.filter((p) => p.id !== id) };
}

export function formatUpdated(ts: number) {
  try {
    return new Intl.DateTimeFormat("de-DE", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(new Date(ts));
  } catch {
    return new Date(ts).toLocaleString("de-DE");
  }
}
