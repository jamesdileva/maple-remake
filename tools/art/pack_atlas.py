"""Packer stage of the art pipeline.

Takes the Blender manifest + PNG frames, packs them into one horizontal strip
per animation, writes the game-ready atlas PNG + JSON for mobs and effects, and
emits a review contact sheet.

Usage:
    python tools/art/pack_atlas.py <manifest.json> <out_root>

Writes:
    <out_root>/assets/art/mobs/<id>.png + .json
    <out_root>/assets/art/effects/<effect_id>.png + .json
    <manifest_dir>/contact_sheet.png
"""

import json
import os
import sys

from PIL import Image, ImageDraw


def load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def pack_group(manifest_dir, cell, animations, out_png, out_json, res_path):
    cell_w, cell_h = cell
    columns = max(entry["count"] for entry in animations.values())
    rows = len(animations)
    atlas = Image.new("RGBA", (cell_w * columns, cell_h * rows), (0, 0, 0, 0))
    frames_meta = {}
    for row, (name, entry) in enumerate(animations.items()):
        regions = []
        for column, relative in enumerate(entry["files"]):
            frame = Image.open(os.path.join(manifest_dir, relative)).convert("RGBA")
            x = column * cell_w
            y = row * cell_h
            atlas.paste(frame, (x, y))
            regions.append([x, y, cell_w, cell_h])
        frames_meta[name] = {"fps": entry["fps"], "loop": entry.get("loop", False), "frames": regions}
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    atlas.save(out_png)
    with open(out_json, "w", encoding="utf-8") as handle:
        json.dump({"image": res_path, "cell": [cell_w, cell_h], "animations": frames_meta}, handle, indent=2)
    return frames_meta


def contact_sheet(manifest_dir, manifest, out_path):
    cell_w, cell_h = manifest["cell"]
    rows = len(manifest["animations"]) + len(manifest.get("effects", {}))
    columns = max(
        [entry["count"] for entry in manifest["animations"].values()]
        + [entry["count"] for entry in manifest.get("effects", {}).values() or [{"count": 1}]]
    )
    sheet = Image.new("RGBA", (cell_w * columns, cell_h * rows), (26, 30, 34, 255))
    draw = ImageDraw.Draw(sheet)
    row = 0
    for name, entry in manifest["animations"].items():
        for column, relative in enumerate(entry["files"]):
            sheet.paste(Image.open(os.path.join(manifest_dir, relative)).convert("RGBA"), (column * cell_w, row * cell_h), Image.open(os.path.join(manifest_dir, relative)).convert("RGBA"))
        draw.text((4, row * cell_h + 2), name, fill=(240, 240, 240, 255))
        row += 1
    for name, entry in manifest.get("effects", {}).items():
        for column, relative in enumerate(entry["files"]):
            sheet.paste(Image.open(os.path.join(manifest_dir, relative)).convert("RGBA"), (column * cell_w, row * cell_h), Image.open(os.path.join(manifest_dir, relative)).convert("RGBA"))
        draw.text((4, row * cell_h + 2), name, fill=(240, 240, 240, 255))
        row += 1
    sheet.save(out_path)


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: pack_atlas.py <manifest.json> <repo_root>")
    manifest_path = os.path.abspath(sys.argv[1])
    out_root = os.path.abspath(sys.argv[2])
    manifest_dir = os.path.dirname(manifest_path)
    manifest = load_json(manifest_path)
    mob_id = manifest["id"]

    mob_png = os.path.join(out_root, "assets", "art", "mobs", mob_id + ".png")
    mob_json = os.path.join(out_root, "assets", "art", "mobs", mob_id + ".json")
    pack_group(
        manifest_dir,
        manifest["cell"],
        manifest["animations"],
        mob_png,
        mob_json,
        "res://assets/art/mobs/%s.png" % mob_id,
    )

    for effect_id, entry in manifest.get("effects", {}).items():
        effect_png = os.path.join(out_root, "assets", "art", "effects", effect_id + ".png")
        effect_json = os.path.join(out_root, "assets", "art", "effects", effect_id + ".json")
        pack_group(
            manifest_dir,
            entry["cell"],
            {effect_id: entry},
            effect_png,
            effect_json,
            "res://assets/art/effects/%s.png" % effect_id,
        )

    contact_sheet(manifest_dir, manifest, os.path.join(manifest_dir, "contact_sheet.png"))
    print("PACK_OK %s" % mob_png)


if __name__ == "__main__":
    main()
