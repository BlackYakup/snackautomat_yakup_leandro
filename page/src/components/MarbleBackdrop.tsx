"use client";

type Props = {
  variant?: "page" | "deck" | "hero";
  className?: string;
};

/** Dekorative Marmor-/Facetten-Ebenen für Light Mode */
export function MarbleBackdrop({ variant = "page", className = "" }: Props) {
  return (
    <div className={`marble-backdrop marble-${variant} ${className}`} aria-hidden>
      <div className="marble-layer marble-soft" />
      <div className="marble-layer marble-facet-glow" />
      {variant === "hero" && <div className="marble-layer marble-hero-photo" />}
      {variant === "deck" && <div className="marble-layer marble-stage-photo" />}
      <div className="marble-layer marble-facet-sheen" />
    </div>
  );
}
