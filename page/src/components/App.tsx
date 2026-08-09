"use client";

import { useCallback, useEffect, useState } from "react";
import { Library } from "./Library";
import { Presentation } from "./Presentation";
import {
  loadLibrary,
  saveLibrary,
  upsertPresentation,
  type LibraryStore,
  type StoredPresentation,
} from "@/lib/presentations";

export function App() {
  const [store, setStore] = useState<LibraryStore | null>(null);
  const [activeId, setActiveId] = useState<string | null>(null);

  useEffect(() => {
    setStore(loadLibrary());
  }, []);

  const persist = useCallback((next: LibraryStore) => {
    setStore(next);
    saveLibrary(next);
  }, []);

  const active: StoredPresentation | null =
    store && activeId ? (store.items.find((p) => p.id === activeId) ?? null) : null;

  if (!store) {
    return (
      <div className="library-boot">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/brand/facet-emblem.png" alt="" width={72} height={72} />
        <em>Lade Bibliothek…</em>
      </div>
    );
  }

  if (active) {
    return (
      <Presentation
        presentation={active}
        onBack={() => setActiveId(null)}
        onUpdate={(next) => persist(upsertPresentation(store, next))}
      />
    );
  }

  return (
    <Library
      store={store}
      onStoreChange={persist}
      onOpen={(id) => setActiveId(id)}
    />
  );
}
