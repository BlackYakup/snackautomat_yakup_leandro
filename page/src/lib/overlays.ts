export type OverlayKind = "text" | "box" | "image";

export type OverlayEl = {
  id: string;
  kind: OverlayKind;
  x: number;
  y: number;
  w: number;
  h: number;
  text?: string;
  fontSize?: number;
  color?: string;
  bg?: string;
  src?: string;
  /** object-position style crop hint, e.g. "center top" */
  objectPosition?: string;
  /** zoom for crop feel */
  objectZoom?: number;
  z?: number;
};

export type OverlayDoc = Record<string, OverlayEl[]>;

export function uid(prefix = "el") {
  return `${prefix}_${Math.random().toString(36).slice(2, 9)}`;
}

export function createText(): OverlayEl {
  return {
    id: uid("txt"),
    kind: "text",
    x: 28,
    y: 35,
    w: 40,
    h: 12,
    text: "Neuer Text",
    fontSize: 22,
    color: "#e8eef2",
    bg: "transparent",
    z: 10,
  };
}

export function createBox(): OverlayEl {
  return {
    id: uid("box"),
    kind: "box",
    x: 30,
    y: 30,
    w: 35,
    h: 22,
    text: "Notiz",
    fontSize: 16,
    color: "#e8eef2",
    bg: "rgba(18, 26, 32, 0.88)",
    z: 10,
  };
}

export function createImage(src: string): OverlayEl {
  return {
    id: uid("img"),
    kind: "image",
    x: 25,
    y: 20,
    w: 45,
    h: 40,
    src,
    objectPosition: "center",
    objectZoom: 1,
    z: 10,
  };
}
