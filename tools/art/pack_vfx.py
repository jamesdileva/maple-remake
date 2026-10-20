"""Packer stage of the class-VFX pipeline.

Packs each class's effect frames into one atlas with a row per effect, writes the
game-ready PNG + JSON (animation metadata, matching the mob atlas shape), and
emits a review contact sheet.

Usage:
    python tools/art/pack_vfx.py <manifest.json> <out_root>

Writes:
    <out_root>/assets/art/effects/<id>_vfx.png + .json
    <manifest_dir>/contact_sheet.png
"""

import json
import os
import sys

from PIL import Image, ImageDraw


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: pack_vfx.py <manifest.json> <repo_root>")
    manifest_path = os.path.abspath(sys.argv[1])
    out_root = os.path.abspath(sys.argv[2])
    manifest_dir = os.path.dirname(manifest_path)
    manifest = load_json(manifest_path)
    vfx_id = manifest["id"]
    cell_w, cell_h = manifest["cell"]
    effects = manifest["effects"]

    columns = max(entry["count"] for entry in effects.values())
    atlas = Image.new("RGBA", (cell_w * columns, cell_h * len(effects)), (0, 0, 0, 0))
    animations = {}
    for row, (name, entry) in enumerate(effects.items()):
        regions = []
        for column, relative in enumerate(entry["files"]):
            frame = Image.open(os.path.join(manifest_dir, relative)).convert("RGBA")
            x = column * cell_w
            y = row * cell_h
            atlas.paste(frame, (x, y))
            regions.append([x, y, cell_w, cell_h])
        animations[name] = {"fps": entry["fps"], "loop": entry.get("loop", False), "frames": regions}

    out_dir = os.path.join(out_root, "assets", "art", "effects")
    os.makedirs(out_dir, exist_ok=True)
    png = os.path.join(out_dir, vfx_id + "_vfx.png")
    atlas.save(png)
    with open(os.path.join(out_dir, vfx_id + "_vfx.json"), "w", encoding="utf-8") as handle:
        json.dump({"image": "res://assets/art/effects/%s_vfx.png" % vfx_id, "cell": [cell_w, cell_h], "animations": animations}, handle, indent=2)

    sheet = Image.new("RGBA", (cell_w * columns, cell_h * len(effects)), (26, 30, 34, 255))
    draw = ImageDraw.Draw(sheet)
    for row, (name, entry) in enumerate(effects.items()):
        for column, relative in enumerate(entry["files"]):
            frame = Image.open(os.path.join(manifest_dir, relative)).convert("RGBA")
            sheet.paste(frame, (column * cell_w, row * cell_h), frame)
        draw.text((4, row * cell_h + 2), name, fill=(240, 240, 240, 255))
    sheet.save(os.path.join(manifest_dir, "contact_sheet.png"))

    print("PACK_OK %s (%d effects)" % (png, len(effects)))


if __name__ == "__main__":
    main()
