"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  createBox,
  createImage,
  createText,
  type OverlayEl,
  uid,
} from "@/lib/overlays";

type Props = {
  elements: OverlayEl[];
  editing: boolean;
  onChange: (els: OverlayEl[]) => void;
};

type DragState = {
  id: string;
  ox: number;
  oy: number;
  sw: number;
  sh: number;
  startX: number;
  startY: number;
  mode: "move" | "resize";
};

export function SlideEditor({ elements, editing, onChange }: Props) {
  const rootRef = useRef<HTMLDivElement>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [clipboard, setClipboard] = useState<OverlayEl | null>(null);
  const drag = useRef<DragState | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const selectedEl = elements.find((e) => e.id === selected) ?? null;

  const update = useCallback(
    (id: string, patch: Partial<OverlayEl>) => {
      onChange(elements.map((e) => (e.id === id ? { ...e, ...patch } : e)));
    },
    [elements, onChange],
  );

  const remove = useCallback(
    (id: string) => {
      onChange(elements.filter((e) => e.id !== id));
      setSelected(null);
    },
    [elements, onChange],
  );

  const add = (el: OverlayEl) => {
    onChange([...elements, el]);
    setSelected(el.id);
    setMenuOpen(false);
  };

  useEffect(() => {
    if (!editing) {
      setSelected(null);
      setMenuOpen(false);
    }
  }, [editing]);

  useEffect(() => {
    if (!editing) return;
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;

      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "c" && selectedEl) {
        e.preventDefault();
        setClipboard(structuredClone(selectedEl));
      }
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "v" && clipboard) {
        e.preventDefault();
        const copy: OverlayEl = {
          ...structuredClone(clipboard),
          id: uid(clipboard.kind),
          x: Math.min(80, clipboard.x + 3),
          y: Math.min(80, clipboard.y + 3),
        };
        onChange([...elements, copy]);
        setSelected(copy.id);
      }
      if ((e.key === "Delete" || e.key === "Backspace") && selected) {
        e.preventDefault();
        remove(selected);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [editing, selected, selectedEl, clipboard, elements, onChange, remove]);

  useEffect(() => {
    const onMove = (e: PointerEvent) => {
      const d = drag.current;
      const root = rootRef.current;
      if (!d || !root) return;
      const rect = root.getBoundingClientRect();
      const dx = ((e.clientX - d.startX) / rect.width) * 100;
      const dy = ((e.clientY - d.startY) / rect.height) * 100;
      if (d.mode === "move") {
        update(d.id, {
          x: Math.max(0, Math.min(92, d.ox + dx)),
          y: Math.max(0, Math.min(92, d.oy + dy)),
        });
      } else {
        update(d.id, {
          w: Math.max(8, Math.min(95, d.sw + dx)),
          h: Math.max(6, Math.min(90, d.sh + dy)),
        });
      }
    };
    const onUp = () => {
      drag.current = null;
    };
    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onUp);
    return () => {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
    };
  }, [update]);

  const startDrag = (e: React.PointerEvent, el: OverlayEl, mode: "move" | "resize") => {
    if (!editing) return;
    e.stopPropagation();
    e.preventDefault();
    setSelected(el.id);
    drag.current = {
      id: el.id,
      ox: el.x,
      oy: el.y,
      sw: el.w,
      sh: el.h,
      startX: e.clientX,
      startY: e.clientY,
      mode,
    };
  };

  const onPickImage = (file: File | null) => {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === "string") add(createImage(reader.result));
    };
    reader.readAsDataURL(file);
  };

  return (
    <div
      ref={rootRef}
      className={`slide-editor ${editing ? "is-editing" : ""}`}
      onPointerDown={() => {
        if (editing) setSelected(null);
      }}
    >
      {elements.map((el) => (
        <div
          key={el.id}
          className={`ov-el ov-${el.kind} ${selected === el.id ? "selected" : ""}`}
          style={{
            left: `${el.x}%`,
            top: `${el.y}%`,
            width: `${el.w}%`,
            height: `${el.h}%`,
            zIndex: el.z ?? 10,
            color: el.color,
            background: el.kind === "image" ? "transparent" : el.bg,
            fontSize: el.fontSize ? `${el.fontSize}px` : undefined,
          }}
          onPointerDown={(e) => startDrag(e, el, "move")}
        >
          {el.kind === "image" && el.src ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={el.src}
              alt=""
              draggable={false}
              style={{
                objectPosition: el.objectPosition ?? "center",
                transform: `scale(${el.objectZoom ?? 1})`,
              }}
            />
          ) : editing && selected === el.id ? (
            <textarea
              value={el.text ?? ""}
              onChange={(e) => update(el.id, { text: e.target.value })}
              onPointerDown={(e) => e.stopPropagation()}
              onClick={(e) => e.stopPropagation()}
            />
          ) : (
            <div className="ov-text">{el.text}</div>
          )}

          {editing && selected === el.id && (
            <>
              <button
                type="button"
                className="ov-del"
                onClick={(e) => {
                  e.stopPropagation();
                  remove(el.id);
                }}
                title="Löschen"
              >
                ×
              </button>
              <div className="ov-resize" onPointerDown={(e) => startDrag(e, el, "resize")} />
            </>
          )}
        </div>
      ))}

      {editing && (
        <div className="edit-dock" onPointerDown={(e) => e.stopPropagation()}>
          <button type="button" className="dock-btn" onClick={() => setMenuOpen((v) => !v)}>
            + Hinzufügen
          </button>
          {menuOpen && (
            <div className="edit-menu">
              <button type="button" onClick={() => add(createText())}>
                Text
              </button>
              <button type="button" onClick={() => add(createBox())}>
                Kasten
              </button>
              <button type="button" onClick={() => fileRef.current?.click()}>
                Bild
              </button>
            </div>
          )}
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            hidden
            onChange={(e) => onPickImage(e.target.files?.[0] ?? null)}
          />
          {selectedEl?.kind === "image" && (
            <div className="edit-image-tools">
              <label>
                Zuschnitt
                <select
                  value={selectedEl.objectPosition ?? "center"}
                  onChange={(e) => update(selectedEl.id, { objectPosition: e.target.value })}
                >
                  <option value="center">Mitte</option>
                  <option value="top">Oben</option>
                  <option value="bottom">Unten</option>
                  <option value="left">Links</option>
                  <option value="right">Rechts</option>
                </select>
              </label>
              <label>
                Zoom
                <input
                  type="range"
                  min={1}
                  max={2.5}
                  step={0.05}
                  value={selectedEl.objectZoom ?? 1}
                  onChange={(e) => update(selectedEl.id, { objectZoom: Number(e.target.value) })}
                />
              </label>
            </div>
          )}
          {selectedEl && selectedEl.kind !== "image" && (
            <div className="edit-image-tools">
              <label>
                Schrift
                <input
                  type="range"
                  min={12}
                  max={48}
                  value={selectedEl.fontSize ?? 18}
                  onChange={(e) => update(selectedEl.id, { fontSize: Number(e.target.value) })}
                />
              </label>
            </div>
          )}
          <span className="dock-hint">Ziehen · Strg+C/V · Entf</span>
        </div>
      )}
    </div>
  );
}
