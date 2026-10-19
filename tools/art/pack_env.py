"""Packer stage of the environment pipeline.

Takes the Blender env manifest + prop PNGs, packs one horizontal strip, writes
the game-ready kit atlas PNG + JSON, and emits a review contact sheet.

Usage:
    python tools/art/pack_env.py <manifest.json> <out_root>

Writes:
    <out_root>/assets/art/env/<id>.png + .json
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
        raise SystemExit("usage: pack_env.py <manifest.json> <repo_root>")
    manifest_path = os.path.abspath(sys.argv[1])
    out_root = os.path.abspath(sys.argv[2])
    manifest_dir = os.path.dirname(manifest_path)
    manifest = load_json(manifest_path)
    kit_id = manifest["id"]
    cell_w, cell_h = manifest["cell"]
    props = manifest["props"]

    atlas = Image.new("RGBA", (cell_w * len(props), cell_h), (0, 0, 0, 0))
    meta = {}
    for column, (name, entry) in enumerate(props.items()):
        frame = Image.open(os.path.join(manifest_dir, entry["file"])).convert("RGBA")
        atlas.paste(frame, (column * cell_w, 0))
        meta[name] = {
            "region": [column * cell_w, 0, cell_w, cell_h],
            "pivot": entry.get("pivot", [0.0, cell_h * 0.5]),
            "default_scale": entry.get("default_scale", 1.0),
            "archetype": entry.get("archetype", name),
        }

    out_dir = os.path.join(out_root, "assets", "art", "env")
    os.makedirs(out_dir, exist_ok=True)
    png = os.path.join(out_dir, kit_id + ".png")
    atlas.save(png)
    with open(os.path.join(out_dir, kit_id + ".json"), "w", encoding="utf-8") as handle:
        json.dump({"image": "res://assets/art/env/%s.png" % kit_id, "cell": [cell_w, cell_h], "props": meta}, handle, indent=2)

    sheet = Image.new("RGBA", (cell_w * len(props), cell_h), (26, 30, 34, 255))
    draw = ImageDraw.Draw(sheet)
    for column, (name, entry) in enumerate(props.items()):
        frame = Image.open(os.path.join(manifest_dir, entry["file"])).convert("RGBA")
        sheet.paste(frame, (column * cell_w, 0), frame)
        draw.text((column * cell_w + 4, 2), name, fill=(240, 240, 240, 255))
    sheet.save(os.path.join(manifest_dir, "contact_sheet.png"))

    print("PACK_OK %s (%d props)" % (png, len(props)))


if __name__ == "__main__":
    main()
