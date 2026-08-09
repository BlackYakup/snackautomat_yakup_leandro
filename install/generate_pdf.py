#!/usr/bin/env python3
"""Convert install/*.md documentation to PDF.

Primary: pandoc (only if it actually produces a non-empty PDF).
Fallback: reportlab — tables, images, code/mermaid fences, headings.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DOCS = ("Root", "Control", "Dependencies", "Paths", "Presentation")

IMG_RE = re.compile(r"!\[([^\]]*)\]\(([^)]+)\)")
LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\)")


def ensure_dir() -> None:
    os.makedirs(ROOT, exist_ok=True)


def run(cmd: list[str]) -> bool:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, check=False)
        return r.returncode == 0
    except Exception:
        return False


def try_pandoc_pdf(md: Path, pdf: Path) -> bool:
    """Try pandoc. Many installs need LaTeX for PDF — treat any failure as miss."""
    if not shutil.which("pandoc"):
        return False
    if pdf.exists():
        try:
            pdf.unlink()
        except OSError:
            pass
    # Prefer HTML engine if available (embeds images without LaTeX)
    for engine_args in (
        ["--pdf-engine=wkhtmltopdf"],
        ["--pdf-engine=weasyprint"],
        [],
    ):
        cmd = ["pandoc", str(md), "-o", str(pdf), f"--resource-path={ROOT}"] + engine_args
        ok = run(cmd)
        if ok and pdf.is_file() and pdf.stat().st_size > 0:
            return True
        if pdf.exists():
            try:
                pdf.unlink()
            except OSError:
                pass
    return False


def _ensure_reportlab():
    try:
        from reportlab.lib.pagesizes import A4  # noqa: F401
    except ImportError:
        print("  installing reportlab...")
        if not run([sys.executable, "-m", "pip", "install", "reportlab", "-q"]):
            raise RuntimeError("reportlab install failed")
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import (
        Image,
        KeepTogether,
        Paragraph,
        Preformatted,
        SimpleDocTemplate,
        Spacer,
        Table,
        TableStyle,
    )

    return colors, A4, ParagraphStyle, getSampleStyleSheet, mm, Image, KeepTogether, Paragraph, Preformatted, SimpleDocTemplate, Spacer, Table, TableStyle


def _esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _inline_to_para(text: str) -> str:
    text = IMG_RE.sub("", text)
    text = LINK_RE.sub(r"\1", text)
    out: list[str] = []
    pos = 0
    pattern = re.compile(r"\*\*(.+?)\*\*|`([^`]+)`")
    for m in pattern.finditer(text):
        out.append(_esc(text[pos : m.start()]))
        if m.group(1) is not None:
            out.append(f"<b>{_esc(m.group(1))}</b>")
        else:
            out.append(
                f"<font face='Courier' size='8'>{_esc(m.group(2))}</font>"
            )
        pos = m.end()
    out.append(_esc(text[pos:]))
    return "".join(out)

def _is_table_sep(line: str) -> bool:
    s = line.strip()
    if not s.startswith("|"):
        return False
    cells = [c.strip() for c in s.strip("|").split("|")]
    return all(re.fullmatch(r":?-{3,}:?", c or "-") for c in cells if c is not None)


def _parse_table_row(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def _resolve_image(src: str) -> Path | None:
    raw = src.strip().replace("\\", "/")
    candidates = [
        ROOT / raw,
        ROOT / Path(raw).name,
        ROOT / "previews" / Path(raw).name,
    ]
    if raw.startswith("install/"):
        candidates.insert(0, ROOT.parent / raw)
    for c in candidates:
        if c.is_file():
            return c
    return None


def md_to_reportlab(md: Path, pdf: Path) -> bool:
    (
        colors,
        A4,
        ParagraphStyle,
        getSampleStyleSheet,
        mm,
        Image,
        KeepTogether,
        Paragraph,
        Preformatted,
        SimpleDocTemplate,
        Spacer,
        Table,
        TableStyle,
    ) = _ensure_reportlab()

    text = md.read_text(encoding="utf-8")
    styles = getSampleStyleSheet()
    h1 = ParagraphStyle("H1x", parent=styles["Heading1"], fontSize=16, spaceAfter=8, spaceBefore=6)
    h2 = ParagraphStyle("H2x", parent=styles["Heading2"], fontSize=13, spaceAfter=6, spaceBefore=8)
    h3 = ParagraphStyle("H3x", parent=styles["Heading3"], fontSize=11, spaceAfter=4, spaceBefore=6)
    body = ParagraphStyle("Bodyx", parent=styles["BodyText"], fontSize=9, leading=12)
    code = ParagraphStyle(
        "Codex", parent=styles["Code"], fontSize=7.0, leading=8.5, fontName="Courier"
    )
    cell = ParagraphStyle("Cellx", parent=styles["BodyText"], fontSize=7.5, leading=9)
    caption = ParagraphStyle("Capx", parent=styles["BodyText"], fontSize=8, textColor=colors.grey)

    story: list = []
    lines = text.splitlines()
    i = 0
    page_w = A4[0] - 32 * mm

    def flush_code(buf: list[str], lang: str = "") -> None:
        if not buf:
            return
        label = f"[{lang}] " if lang else ""
        block = "\n".join(buf)
        # Soft-wrap very long lines for PDF width
        wrapped: list[str] = []
        for ln in block.splitlines() or [""]:
            while len(ln) > 110:
                wrapped.append(ln[:110])
                ln = ln[110:]
            wrapped.append(ln)
        if label:
            story.append(Paragraph(_esc(label.strip()), caption))
        story.append(Preformatted("\n".join(wrapped), code))
        story.append(Spacer(1, 3 * mm))

    while i < len(lines):
        line = lines[i]

        # Fenced code / mermaid / ascii trees
        if line.strip().startswith("```"):
            lang = line.strip()[3:].strip()
            buf: list[str] = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                buf.append(lines[i])
                i += 1
            flush_code(buf, lang)
            i += 1
            continue

        # Markdown table
        if "|" in line and i + 1 < len(lines) and _is_table_sep(lines[i + 1]):
            rows: list[list[str]] = [_parse_table_row(line)]
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(_parse_table_row(lines[i]))
                i += 1
            data = [
                [Paragraph(_inline_to_para(c), cell) for c in row]
                for row in rows
            ]
            ncol = max(len(r) for r in data) if data else 1
            for row in data:
                while len(row) < ncol:
                    row.append(Paragraph("", cell))
            col_w = page_w / ncol
            tbl = Table(data, colWidths=[col_w] * ncol, repeatRows=1)
            tbl.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, 0), colors.Color(0.92, 0.92, 0.94)),
                        ("GRID", (0, 0), (-1, -1), 0.4, colors.grey),
                        ("VALIGN", (0, 0), (-1, -1), "TOP"),
                        ("LEFTPADDING", (0, 0), (-1, -1), 3),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                        ("TOPPADDING", (0, 0), (-1, -1), 2),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
                    ]
                )
            )
            story.append(tbl)
            story.append(Spacer(1, 3 * mm))
            continue

        # Image alone or with surrounding text
        img_m = IMG_RE.search(line)
        if img_m and line.strip().startswith("!["):
            alt, src = img_m.group(1), img_m.group(2)
            path = _resolve_image(src)
            if path:
                try:
                    img = Image(str(path))
                    max_w = page_w
                    max_h = 90 * mm
                    iw, ih = img.imageWidth, img.imageHeight
                    scale = min(max_w / iw, max_h / ih, 1.0)
                    img.drawWidth = iw * scale
                    img.drawHeight = ih * scale
                    parts = [img]
                    if alt:
                        parts.append(Paragraph(_esc(alt), caption))
                    parts.append(Spacer(1, 3 * mm))
                    story.append(KeepTogether(parts))
                except Exception as e:
                    story.append(Paragraph(_esc(f"[Bild fehlt: {src} ({e})]"), caption))
            else:
                story.append(Paragraph(_esc(f"[Bild nicht gefunden: {src}]"), caption))
            i += 1
            continue

        if line.startswith("# "):
            story.append(Paragraph(_inline_to_para(line[2:].strip()), h1))
        elif line.startswith("## "):
            story.append(Paragraph(_inline_to_para(line[3:].strip()), h2))
        elif line.startswith("### "):
            story.append(Paragraph(_inline_to_para(line[4:].strip()), h3))
        elif line.strip() == "---":
            story.append(Spacer(1, 3 * mm))
        elif line.strip() == "":
            story.append(Spacer(1, 1.5 * mm))
        elif line.startswith("> "):
            story.append(Paragraph(_inline_to_para(line[2:].strip()), body))
        elif line.strip().startswith("- ") or line.strip().startswith("* "):
            story.append(Paragraph("• " + _inline_to_para(line.strip()[2:]), body))
        else:
            # Strip leading checklist markers
            cleaned = re.sub(r"^- \[[ xX]\]\s*", "", line.strip())
            if cleaned != line.strip():
                story.append(Paragraph("☐ " + _inline_to_para(cleaned), body))
            else:
                story.append(Paragraph(_inline_to_para(line), body))
        i += 1

    doc = SimpleDocTemplate(
        str(pdf),
        pagesize=A4,
        leftMargin=16 * mm,
        rightMargin=16 * mm,
        topMargin=14 * mm,
        bottomMargin=14 * mm,
        title=md.stem,
    )
    doc.build(story)
    return pdf.is_file() and pdf.stat().st_size > 0


def convert_one(name: str) -> bool:
    md = ROOT / f"{name}.md"
    pdf = ROOT / f"{name}.pdf"
    if not md.is_file():
        print("missing", md)
        return False
    print("[pdf]", md.name)
    # Prefer reportlab for reliable tables/images on Windows without LaTeX
    if md_to_reportlab(md, pdf):
        print("  OK reportlab", pdf.stat().st_size)
        return True
    print("  reportlab failed -> trying pandoc")
    if try_pandoc_pdf(md, pdf):
        print("  OK pandoc", pdf.stat().st_size)
        return True
    print("  FAILED")
    return False


def main() -> int:
    ensure_dir()
    ok = sum(1 for n in DOCS if convert_one(n))
    print(f"done {ok}/{len(DOCS)}")
    return 0 if ok == len(DOCS) else 1


if __name__ == "__main__":
    raise SystemExit(main())
