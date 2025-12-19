#!/usr/bin/env python3
"""
Bitmap (PNG/BMP) -> MARS ASM sprite (.word) + blit macro (unrolled by default)

- Each pixel becomes: .word 0x00RRGGBB (row-major)
- Macro copies sprite into bitmap buffer base in $s0.

Usage example:
  python tools/gen_asm_from_bitmap.py --input menu.bmp --out menuSprite.asm --macro drawMenu

Notes:
- Before calling macro(), put bitmap base address in $s0 (e.g. 0x10000000).
- Clobbers: $t0-$t9 (depending on unroll).
"""

import argparse
from PIL import Image
import os

def sanitize_label(s: str) -> str:
    out = []
    for ch in s:
        if ch.isalnum() or ch == "_":
            out.append(ch)
        else:
            out.append("_")
    if not out or out[0].isdigit():
        out.insert(0, "_")
    return "".join(out)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="PNG/BMP input image (path or name)")
    ap.add_argument("--out", required=True, help="output ASM filename")
    ap.add_argument("--macro", default="drawSprite", help="macro name (default drawSprite)")
    ap.add_argument("--label", default=None, help="data label (optional)")
    ap.add_argument("--words_per_line", type=int, default=8)
    ap.add_argument("--unroll", type=int, default=8, help="unroll factor (1..8), default 8")
    ap.add_argument("--indir", default="sprites", help="input directory (default sprites)")
    ap.add_argument("--outdir", default="sprites", help="output directory (default sprites)")
    args = ap.parse_args()

    in_path = args.input
    if not os.path.isabs(in_path):
        in_path = os.path.join(args.indir, in_path)

    img = Image.open(in_path).convert("RGBA")
    w, h = img.size
    total = w * h
    px = img.load()

    macro = sanitize_label(args.macro)
    label = sanitize_label(args.label if args.label else f"{macro}_sprite")

    # Build words
    pixels = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            pixels.append(f"0x00{r:02X}{g:02X}{b:02X}")

    # Clamp unroll (we emit efficiently up to 8)
    unroll = int(args.unroll)
    if unroll < 1:
        unroll = 1
    if unroll > 8:
        unroll = 8

    # Reg choices (match your previous style)
    # Always: $t1=src, $t2=dst, $t3=count
    payload_regs_8 = ["$t0", "$t4", "$t5", "$t6", "$t7", "$t8", "$t9", "$t0"]  # last reuse t0
    payload_pool = ["$t0", "$t4", "$t5", "$t6", "$t7", "$t8", "$t9"]
    def payload_regs(n: int):
        if n == 8:
            return payload_regs_8
        return payload_pool[:n]

    # Emit ASM
    lines = []
    lines += [
        "# Auto-generated from bitmap",
        f"# Size: {w}x{h} ({total} pixels)",
        f"# Before calling {macro}(), put bitmap base in $s0 (e.g. 0x10000000).",
        f"# Unroll factor: {unroll}",
        "# Clobbers: $t0-$t9 (depending on unroll)",
        "",
        ".data",
        ".align 2",
        f"{label}:",
    ]

    wpl = max(1, int(args.words_per_line))
    for i in range(0, total, wpl):
        lines.append("    .word " + ", ".join(pixels[i:i+wpl]))

    loop_lbl = f"{macro}_loop"
    rem_lbl  = f"{macro}_rem"
    done_lbl = f"{macro}_done"

    lines += [
        "",
        ".text",
        f".macro {macro}",
        "    # $s0 = bitmap base (dst)",
        f"    la    $t1, {label}      # src pointer",
        "    move  $t2, $s0          # dst pointer",
        f"    li    $t3, {total}      # pixels remaining",
        "",
    ]

    if unroll == 1:
        lines += [
            f"{loop_lbl}:",
            f"    beqz  $t3, {done_lbl}",
            "    nop",
            "    lw    $t0, 0($t1)",
            "    sw    $t0, 0($t2)",
            "    addiu $t1, $t1, 4",
            "    addiu $t2, $t2, 4",
            "    addiu $t3, $t3, -1",
            f"    b     {loop_lbl}",
            "    nop",
            f"{done_lbl}:",
            ".end_macro",
            "",
        ]
    else:
        lines += [
            f"{loop_lbl}:",
            f"    slti  $t0, $t3, {unroll}   # $t0=1 if remaining < unroll",
            f"    bnez  $t0, {rem_lbl}",
            "    nop",
        ]

        regs = payload_regs(unroll)
        for i in range(unroll):
            off = i * 4
            r = regs[i]
            lines.append(f"    lw    {r}, {off}($t1)")
            lines.append(f"    sw    {r}, {off}($t2)")

        lines += [
            f"    addiu $t1, $t1, {unroll*4}",
            f"    addiu $t2, $t2, {unroll*4}",
            f"    addiu $t3, $t3, -{unroll}",
            f"    b     {loop_lbl}",
            "    nop",
            "",
            f"{rem_lbl}:",
            f"    beqz  $t3, {done_lbl}",
            "    nop",
            f"{rem_lbl}_loop:",
            "    lw    $t4, 0($t1)",
            "    sw    $t4, 0($t2)",
            "    addiu $t1, $t1, 4",
            "    addiu $t2, $t2, 4",
            "    addiu $t3, $t3, -1",
            f"    bnez  $t3, {rem_lbl}_loop",
            "    nop",
            "",
            f"{done_lbl}:",
            ".end_macro",
            "",
        ]

    out_path = args.out
    if not os.path.isabs(out_path):
        out_path = os.path.join(args.outdir, out_path)

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"Wrote {out_path} ({w}x{h}={total} pixels) macro={macro} label={label} unroll={unroll}")

if __name__ == "__main__":
    main()
