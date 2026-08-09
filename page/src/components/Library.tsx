"use client";

import { useMemo, useState } from "react";
import { MarbleBackdrop } from "./MarbleBackdrop";
import {
  createPresentation,
  deletePresentation,
  formatUpdated,
  renamePresentation,
  setArchived,
  upsertPresentation,
  type LibraryStore,
  type StoredPresentation,
} from "@/lib/presentations";

type Tab = "active" | "archive";

type Props = {
  store: LibraryStore;
  onStoreChange: (next: LibraryStore) => void;
  onOpen: (id: string) => void;
};

export function Library({ store, onStoreChange, onOpen }: Props) {
  const [tab, setTab] = useState<Tab>("active");
  const [creating, setCreating] = useState(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [from, setFrom] = useState<"template" | "blank">("template");
  const [renameId, setRenameId] = useState<string | null>(null);
  const [renameTitle, setRenameTitle] = useState("");
  const [renameDesc, setRenameDesc] = useState("");

  const list = useMemo(() => {
    return store.items
      .filter((p) => (tab === "archive" ? p.archived : !p.archived))
      .sort((a, b) => b.updatedAt - a.updatedAt);
  }, [store.items, tab]);

  const activeCount = store.items.filter((p) => !p.archived).length;
  const archiveCount = store.items.filter((p) => p.archived).length;

  const submitCreate = () => {
    const item = createPresentation({
      title: title || (from === "template" ? "Snackautomat 3D" : "Neue Präsentation"),
      description,
      from,
    });
    onStoreChange(upsertPresentation(store, item));
    setCreating(false);
    setTitle("");
    setDescription("");
    setFrom("template");
    onOpen(item.id);
  };

  const duplicate = (p: StoredPresentation) => {
    const copy = createPresentation({
      title: `${p.title} (Kopie)`,
      description: p.description,
      from: p,
    });
    onStoreChange(upsertPresentation(store, copy));
  };

  const submitRename = () => {
    if (!renameId) return;
    onStoreChange(renamePresentation(store, renameId, renameTitle, renameDesc));
    setRenameId(null);
  };

  return (
    <div className="library-shell">
      <MarbleBackdrop variant="page" />

      <section className="library-hero-bleed">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className="library-hero-img" src="/brand/marble-hero.png" alt="" />
        <div className="library-hero-veil" />
        <div className="library-hero-inner">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="library-emblem" src="/brand/facet-emblem.png" alt="" />
          <div className="library-hero-copy">
            <p className="library-eyebrow">Präsentationsatelier</p>
            <h1>Snackautomat 3D</h1>
            <p className="library-lead">
              Moderne Decks auf Schwarz-Weiß-Marmor — erstellen, archivieren, vorführen.
            </p>
            <button type="button" className="nav-btn primary library-create" onClick={() => setCreating(true)}>
              Neue Präsentation
            </button>
          </div>
        </div>
      </section>

      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img className="library-vein" src="/brand/marble-vein.png" alt="" />

      <div className="library">
        <div className="library-tabs" role="tablist">
          <button
            type="button"
            role="tab"
            aria-selected={tab === "active"}
            className={tab === "active" ? "on" : ""}
            onClick={() => setTab("active")}
          >
            Aktiv <em>{activeCount}</em>
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={tab === "archive"}
            className={tab === "archive" ? "on" : ""}
            onClick={() => setTab("archive")}
          >
            Archiv <em>{archiveCount}</em>
          </button>
        </div>

        {list.length === 0 ? (
          <div className="library-empty">
            <strong>{tab === "archive" ? "Archiv ist leer" : "Noch keine Präsentation"}</strong>
            <p>
              {tab === "archive"
                ? "Archivierte Decks erscheinen hier und können wiederhergestellt werden."
                : "Lege eine neue Präsentation an oder nutze die Snackautomat-Vorlage."}
            </p>
            {tab === "active" && (
              <button type="button" className="nav-btn primary" onClick={() => setCreating(true)}>
                Erstellen
              </button>
            )}
          </div>
        ) : (
          <ul className="library-grid">
            {list.map((p, i) => (
              <li key={p.id} className="library-card" style={{ animationDelay: `${i * 0.05}s` }}>
                <button type="button" className="library-card-visual" onClick={() => onOpen(p.id)}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={p.kind === "template" ? "/brand/marble-facets.png" : "/brand/marble-stage.png"}
                    alt=""
                  />
                </button>
                <div className="library-card-body">
                  <button type="button" className="library-card-main" onClick={() => onOpen(p.id)}>
                    <span className={`library-kind ${p.kind}`}>
                      {p.kind === "template" ? "Vorlage" : "Eigen"}
                    </span>
                    <strong>{p.title}</strong>
                    <span className="library-desc">
                      {p.description || `${p.slides.length} Folien`}
                    </span>
                    <span className="library-meta">
                      {p.slides.length} Folien · {formatUpdated(p.updatedAt)}
                    </span>
                  </button>
                  <div className="library-actions">
                    <button type="button" onClick={() => onOpen(p.id)}>
                      Öffnen
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setRenameId(p.id);
                        setRenameTitle(p.title);
                        setRenameDesc(p.description);
                      }}
                    >
                      Umbenennen
                    </button>
                    <button type="button" onClick={() => duplicate(p)}>
                      Duplizieren
                    </button>
                    {p.archived ? (
                      <>
                        <button
                          type="button"
                          onClick={() => onStoreChange(setArchived(store, p.id, false))}
                        >
                          Wiederherstellen
                        </button>
                        <button
                          type="button"
                          className="danger"
                          onClick={() => {
                            if (confirm(`„${p.title}“ endgültig löschen?`)) {
                              onStoreChange(deletePresentation(store, p.id));
                            }
                          }}
                        >
                          Löschen
                        </button>
                      </>
                    ) : (
                      <button
                        type="button"
                        onClick={() => onStoreChange(setArchived(store, p.id, true))}
                      >
                        Archivieren
                      </button>
                    )}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      {creating && (
        <div className="save-modal" role="dialog" aria-modal="true">
          <div className="save-card library-modal">
            <h3>Neue Präsentation</h3>
            <label className="field">
              Titel
              <input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="z. B. Zwischenstand KW 12"
                autoFocus
              />
            </label>
            <label className="field">
              Kurzbeschreibung
              <input
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Optional"
              />
            </label>
            <div className="create-source">
              <button
                type="button"
                className={from === "template" ? "on" : ""}
                onClick={() => setFrom("template")}
              >
                Snackautomat-Vorlage
              </button>
              <button
                type="button"
                className={from === "blank" ? "on" : ""}
                onClick={() => setFrom("blank")}
              >
                Leeres Deck
              </button>
            </div>
            <div className="save-actions">
              <button type="button" className="nav-btn" onClick={() => setCreating(false)}>
                Abbrechen
              </button>
              <button type="button" className="nav-btn primary" onClick={submitCreate}>
                Anlegen & öffnen
              </button>
            </div>
          </div>
        </div>
      )}

      {renameId && (
        <div className="save-modal" role="dialog" aria-modal="true">
          <div className="save-card library-modal">
            <h3>Umbenennen</h3>
            <label className="field">
              Titel
              <input value={renameTitle} onChange={(e) => setRenameTitle(e.target.value)} autoFocus />
            </label>
            <label className="field">
              Kurzbeschreibung
              <input value={renameDesc} onChange={(e) => setRenameDesc(e.target.value)} />
            </label>
            <div className="save-actions">
              <button type="button" className="nav-btn" onClick={() => setRenameId(null)}>
                Abbrechen
              </button>
              <button type="button" className="nav-btn primary" onClick={submitRename}>
                Speichern
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
