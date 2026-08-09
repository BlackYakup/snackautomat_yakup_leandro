"use client";

import { useCallback, useRef, useState } from "react";

type Mode = "idle" | "forward" | "back-armed" | "back";

type Props = {
  enabled: boolean;
  canForward: boolean;
  canBack: boolean;
  onForward: () => void;
  onBack: () => void;
};

const HOLD_MS = 3000;

/** Vorwärts: 3s halten. Zurück: Doppelklick, dann 3s halten. */
export function HoldNav({ enabled, canForward, canBack, onForward, onBack }: Props) {
  const [mode, setMode] = useState<Mode>("idle");
  const [progress, setProgress] = useState(0);
  const raf = useRef<number | null>(null);
  const start = useRef(0);
  const lastClick = useRef(0);
  const armedUntil = useRef(0);
  const modeRef = useRef<Mode>("idle");

  const setModeSafe = (m: Mode) => {
    modeRef.current = m;
    setMode(m);
  };

  const clearRaf = () => {
    if (raf.current) cancelAnimationFrame(raf.current);
    raf.current = null;
  };

  const tick = useCallback(
    (kind: "forward" | "back") => {
      const now = performance.now();
      const p = Math.min(1, (now - start.current) / HOLD_MS);
      setProgress(p);
      if (p >= 1) {
        clearRaf();
        setProgress(0);
        setModeSafe("idle");
        armedUntil.current = 0;
        if (kind === "forward") onForward();
        else onBack();
        return;
      }
      raf.current = requestAnimationFrame(() => tick(kind));
    },
    [onBack, onForward],
  );

  const cancelHold = () => {
    if (modeRef.current === "forward" || modeRef.current === "back") {
      clearRaf();
      setProgress(0);
      if (modeRef.current === "back" && Date.now() < armedUntil.current) {
        setModeSafe("back-armed");
      } else {
        setModeSafe("idle");
      }
    }
  };

  const onPointerDown = (e: React.PointerEvent) => {
    if (!enabled || e.button !== 0) return;
    if (
      (e.target as HTMLElement).closest(
        "button, a, input, textarea, select, .edit-dock, .ov-el, .chrome, .hold-ring",
      )
    ) {
      return;
    }

    const now = Date.now();
    const isDouble = now - lastClick.current < 380;
    lastClick.current = now;

    if (isDouble && canBack) {
      clearRaf();
      setProgress(0);
      armedUntil.current = now + 4500;
      setModeSafe("back-armed");
      return;
    }

    if (modeRef.current === "back-armed" && canBack && now < armedUntil.current) {
      e.preventDefault();
      start.current = performance.now();
      setModeSafe("back");
      setProgress(0);
      raf.current = requestAnimationFrame(() => tick("back"));
      return;
    }

    if (canForward) {
      e.preventDefault();
      start.current = performance.now();
      setModeSafe("forward");
      setProgress(0);
      raf.current = requestAnimationFrame(() => tick("forward"));
    }
  };

  if (!enabled) return null;

  return (
    <div
      className="hold-nav-layer"
      onPointerDown={onPointerDown}
      onPointerUp={cancelHold}
      onPointerLeave={cancelHold}
      onPointerCancel={cancelHold}
    >
      {mode === "back-armed" && (
        <div className="hold-armed">Zurück aktiv – 3 Sekunden gedrückt halten</div>
      )}
      {(mode === "forward" || mode === "back") && (
        <div className={`hold-ring ${mode}`}>
          <svg viewBox="0 0 120 120" aria-hidden>
            <circle className="track" cx="60" cy="60" r="52" />
            <circle
              className="bar"
              cx="60"
              cy="60"
              r="52"
              style={{
                strokeDasharray: `${2 * Math.PI * 52}`,
                strokeDashoffset: `${2 * Math.PI * 52 * (1 - progress)}`,
              }}
            />
          </svg>
          <span>{mode === "forward" ? "Weiter" : "Zurück"}</span>
          <small>{Math.max(1, Math.ceil((1 - progress) * 3))}s</small>
        </div>
      )}
    </div>
  );
}
