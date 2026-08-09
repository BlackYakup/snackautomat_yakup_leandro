"use client";

import { useCallback, useEffect, useState } from "react";
import type { Slide } from "@/data/slides";
import { highlightDart } from "./highlightDart";
import { HoldNav } from "./HoldNav";
import { MarbleBackdrop } from "./MarbleBackdrop";
import { SlideEditor } from "./SlideEditor";
import type { OverlayDoc, OverlayEl } from "@/lib/overlays";
import type { StoredPresentation } from "@/lib/presentations";

const TOTAL_MS = 5.5 * 60 * 1000;

type Props = {
  presentation: StoredPresentation;
  onBack: () => void;
  onUpdate: (next: StoredPresentation) => void;
};

export function Presentation({ presentation, onBack, onUpdate }: Props) {
  const slides = presentation.slides;
  const [index, setIndex] = useState(0);
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const [now, setNow] = useState(Date.now());
  const [editing, setEditing] = useState(false);
  const [overlays, setOverlays] = useState<OverlayDoc>(presentation.overlays);
  const [draft, setDraft] = useState<OverlayEl[]>([]);
  const [baseline, setBaseline] = useState<OverlayEl[]>([]);
  const [confirmExit, setConfirmExit] = useState<"edit" | "leave" | null>(null);

  useEffect(() => {
    setIndex(0);
    setStartedAt(null);
    setEditing(false);
    setConfirmExit(null);
    setOverlays(presentation.overlays);
    // Nur beim Wechsel der Präsentation neu laden
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [presentation.id]);

  const slide = slides[Math.min(index, slides.length - 1)];
  const progress = ((index + 1) / slides.length) * 100;
  const elapsed = startedAt ? Math.min(TOTAL_MS, now - startedAt) : 0;
  const remaining = Math.max(0, TOTAL_MS - elapsed);
  const mm = String(Math.floor(remaining / 60000));
  const ss = String(Math.floor((remaining % 60000) / 1000)).padStart(2, "0");
  const overtime = startedAt !== null && remaining === 0;

  const go = useCallback(
    (next: number) => {
      setIndex(Math.max(0, Math.min(slides.length - 1, next)));
      if (startedAt === null) setStartedAt(Date.now());
    },
    [startedAt, slides.length],
  );

  useEffect(() => {
    if (editing) return;
    setDraft(overlays[slide.id] ?? []);
  }, [slide.id, overlays, editing]);

  useEffect(() => {
    const t = window.setInterval(() => setNow(Date.now()), 500);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (editing) return;
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;
      if (e.key === "Escape") onBack();
      if (e.key === "f" || e.key === "F") {
        if (!document.fullscreenElement) document.documentElement.requestFullscreen?.();
        else document.exitFullscreen?.();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [editing, onBack]);

  const dirty = editing && JSON.stringify(draft) !== JSON.stringify(baseline);

  const persistOverlays = (next: OverlayDoc) => {
    setOverlays(next);
    onUpdate({ ...presentation, overlays: next, updatedAt: Date.now() });
  };

  const enterEdit = () => {
    const current = overlays[slide.id] ?? [];
    setBaseline(structuredClone(current));
    setDraft(structuredClone(current));
    setEditing(true);
    setConfirmExit(null);
  };

  const requestExitEdit = () => {
    if (!dirty) {
      setEditing(false);
      return;
    }
    setConfirmExit("edit");
  };

  const saveDraft = () => {
    persistOverlays({ ...overlays, [slide.id]: draft });
    setEditing(false);
    setConfirmExit(null);
  };

  const discardDraft = () => {
    setDraft(structuredClone(baseline));
    setEditing(false);
    setConfirmExit(null);
  };

  const toggleEdit = () => {
    if (editing) requestExitEdit();
    else enterEdit();
  };

  const leaveDeck = () => {
    if (editing && dirty) {
      setConfirmExit("leave");
      return;
    }
    onBack();
  };

  const confirmSave = () => {
    const leaving = confirmExit === "leave";
    saveDraft();
    if (leaving) onBack();
  };

  const confirmDiscard = () => {
    const leaving = confirmExit === "leave";
    discardDraft();
    if (leaving) onBack();
  };

  const visibleEls = editing ? draft : (overlays[slide.id] ?? []);

  return (
    <div className={`deck ${editing ? "deck-editing" : ""}`}>
      <MarbleBackdrop variant="deck" />
      <header className="chrome top">
        <div className="brand">
          <button type="button" className="mark library-back" onClick={leaveDeck} title="Zur Bibliothek">
            SA
          </button>
          <div>
            <strong>{presentation.title}</strong>
            <em>
              Folie {index + 1} / {slides.length}
              {editing ? " · Bearbeitung" : ""}
            </em>
          </div>
        </div>
        <div className="chrome-right">
          <button type="button" className="edit-toggle ghost" onClick={leaveDeck} title="Bibliothek">
            Bibliothek
          </button>
          <button
            type="button"
            className={`edit-toggle ${editing ? "active" : ""}`}
            onClick={toggleEdit}
            title={editing ? "Bearbeitung beenden" : "Folie bearbeiten"}
          >
            {editing ? "Fertig" : "Bearbeiten"}
          </button>
          <div className={`timer ${overtime ? "over" : ""}`}>
            {startedAt ? `${mm}:${ss}` : "5:30"}
            <span>{overtime ? "Zeit um" : "Rest"}</span>
          </div>
        </div>
      </header>

      <div className="progress-track" aria-hidden>
        <div className="progress-fill" style={{ width: `${progress}%` }} />
      </div>

      <main className={`stage stage-${slide.kind}`}>
        <div className="stage-frame">
          <SlideBody slide={slide} />
          <SlideEditor elements={visibleEls} editing={editing} onChange={setDraft} />
          {!editing && (
            <HoldNav
              enabled
              canForward={index < slides.length - 1}
              canBack={index > 0}
              onForward={() => go(index + 1)}
              onBack={() => go(index - 1)}
            />
          )}
        </div>
      </main>

      <footer className="chrome bottom">
        <button
          type="button"
          className="nav-btn"
          onClick={() => go(index - 1)}
          disabled={index === 0 || editing}
        >
          Zurück
        </button>
        <div className="dots" aria-hidden>
          {slides.map((s, i) => (
            <span key={s.id} className={i === index ? "dot on" : "dot"} />
          ))}
        </div>
        <button
          type="button"
          className="nav-btn primary"
          onClick={() => go(index + 1)}
          disabled={index === slides.length - 1 || editing}
        >
          Weiter
        </button>
      </footer>

      {confirmExit && (
        <div className="save-modal" role="dialog" aria-modal="true">
          <div className="save-card">
            <h3>Änderungen speichern?</h3>
            <p>Die Bearbeitungen dieser Folie können gespeichert oder verworfen werden.</p>
            <div className="save-actions">
              <button type="button" className="nav-btn" onClick={confirmDiscard}>
                Verwerfen
              </button>
              <button type="button" className="nav-btn primary" onClick={confirmSave}>
                Speichern
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function SlideBody({ slide }: { slide: Slide }) {
  switch (slide.kind) {
    case "title":
      return (
        <div className="slide title-slide title-plain">
          <div className="title-plain-bg" />
          <div className="title-copy">
            <p className="kicker">Projektarbeit</p>
            <h1>{slide.title}</h1>
            <p className="subtitle">{slide.subtitle}</p>
            <p className="meta">{slide.meta}</p>
          </div>
        </div>
      );
    case "explain":
      return (
        <div className={`slide feature-slide ${slide.image ? "has-img" : ""}`}>
          <div className="copy-panel">
            <p className="kicker">{slide.kicker}</p>
            <h2>{slide.title}</h2>
            <ul>
              {slide.points.map((p) => (
                <li key={p}>{p}</li>
              ))}
            </ul>
          </div>
          {slide.image && (
            <div className="media-frame diagram-frame">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={slide.image} alt="" />
            </div>
          )}
        </div>
      );
    case "diagram":
      return (
        <div className="slide diagram-slide">
          <div className="diagram-head">
            <div>
              <p className="kicker">{slide.kicker}</p>
              <h2>{slide.title}</h2>
            </div>
            <p className="diagram-caption">{slide.caption}</p>
          </div>
          <div className="diagram-frame full">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={slide.image} alt={slide.title} />
          </div>
        </div>
      );
    case "flow":
      return (
        <div className="slide flow-slide">
          <p className="kicker">{slide.kicker}</p>
          <h2>{slide.title}</h2>
          <p className="diagram-caption flow-caption">{slide.caption}</p>
          <div className="flow-track">
            {slide.steps.map((s, i) => (
              <div key={`${s.label}-${i}`} className="flow-node">
                <span className={`flow-box tone-${s.tone}`}>{s.label}</span>
                {i < slide.transitions.length && (
                  <div className="flow-bridge">
                    <i aria-hidden>→</i>
                    <em>{slide.transitions[i]}</em>
                  </div>
                )}
              </div>
            ))}
          </div>
          <div className="legend">
            <span className="lg green">Grün · bereit</span>
            <span className="lg blue">Blau · Zahlung</span>
            <span className="lg yellow">Gelb · Ausgabe</span>
            <span className="lg red">Rot · außer Betrieb</span>
          </div>
        </div>
      );
    case "code":
      return (
        <div className="slide code-slide">
          <div className="code-card">
            <header className="code-card-head">
              <div>
                <p className="kicker">{slide.kicker}</p>
                <h2>{slide.title}</h2>
              </div>
              <p className="code-file">{slide.file}</p>
            </header>

            <div className="code-tags">
              {slide.tags.map((t) => (
                <span key={t} className="code-tag">
                  {t}
                </span>
              ))}
            </div>

            <ul className="code-bullets">
              {slide.explanation.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>

            <pre className="code-block">
              <code>{highlightDart(slide.code.join("\n"))}</code>
            </pre>
          </div>
        </div>
      );
    case "status":
      return (
        <div className="slide status-slide">
          <p className="kicker">{slide.kicker}</p>
          <h2>{slide.title}</h2>
          <p className="status-intro">{slide.intro}</p>
          <div className="status-grid">
            <section className="status-col is-now">
              <header>
                <span className="status-badge">IST</span>
                <h3>Heute verdrahtet</h3>
              </header>
              <ul>
                {slide.now.map((item) => (
                  <li key={item.title}>
                    <strong>{item.title}</strong>
                    <span>{item.detail}</span>
                  </li>
                ))}
              </ul>
            </section>
            <section className="status-col is-next">
              <header>
                <span className="status-badge next">SOLL</span>
                <h3>Geplant als Ausblick</h3>
              </header>
              <ul>
                {slide.next.map((item) => (
                  <li key={item.title}>
                    <strong>{item.title}</strong>
                    <span>{item.detail}</span>
                  </li>
                ))}
              </ul>
            </section>
          </div>
        </div>
      );
    case "closing":
      return (
        <div className="slide closing-slide closing-plain">
          <div className="closing-copy">
            <h1>{slide.title}</h1>
            {slide.lines.map((l) => (
              <p key={l}>{l}</p>
            ))}
          </div>
        </div>
      );
    default:
      return null;
  }
}
