"""Concept board generator for the art pipeline.

Reads a mob spec and renders a palette + silhouette + animation contact sheet to
art_src/concept/<id>_concept.png. This is the automated half of the
"concept -> human approval" stage; the board is what a human reviews before the
approved spec is rendered into sprites.

Usage:
    python tools/art/concept.py <spec.json> <out.png>
"""

import json
import sys

from PIL import Image, ImageDraw


def load_spec(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def rgb(component):
    return tuple(int(max(0.0, min(1.0, value)) * 255.0) for value in component)


def build_board(spec):
    width, height = 640, 360
    board = Image.new("RGBA", (width, height), (26, 30, 34, 255))
    draw = ImageDraw.Draw(board)

    palette = spec["palette"]
    draw.text((16, 12), f"{spec['display_name']}  ({spec['id']})", fill=(235, 240, 235, 255))
    draw.text((16, 30), "concept board - approve before render", fill=(150, 160, 150, 255))

    y = 60
    for name, component in palette.items():
        swatch = rgb(component)
        draw.rectangle([16, y, 52, y + 22], fill=swatch + (255,), outline=(70, 76, 70, 255))
        draw.text((60, y + 5), name, fill=(215, 220, 215, 255))
        y += 28

    panel_x = 240
    draw.rectangle([panel_x, 52, width - 16, height - 16], outline=(60, 66, 60, 255))

    shape = spec["shape"]
    body = rgb(palette["body"])
    highlight = rgb(palette["highlight"])
    outline = rgb(palette["outline"])
    eye = rgb(palette["eye"])

    cell = spec["cell"]
    sprite_height = spec["sprite_height"]
    anims = spec["animations"]
    columns = max(1, len(anims))
    panel_w = (width - 16 - panel_x) // columns
    for index, animation in enumerate(anims):
        cx = panel_x + index * panel_w + panel_w // 2
        cy = 52 + (height - 68) // 2 + 20
        radius = shape["radius"] * sprite_height * 1.1
        draw.ellipse(
            [cx - radius, cy - radius * (1.0 - shape["squash"]), cx + radius, cy + radius],
            fill=body + (255,),
            outline=outline + (255,),
            width=2,
        )
        eye_dx = shape["eye_spacing"] * sprite_height
        eye_r = shape["eye_size"] * sprite_height
        eye_z = cy - radius * 0.15
        for sign in (-1, 1):
            draw.ellipse(
                [cx + sign * eye_dx - eye_r, eye_z - eye_r, cx + sign * eye_dx + eye_r, eye_z + eye_r],
                fill=eye + (255,),
            )
        hl = shape["highlight_size"] * sprite_height
        draw.ellipse([cx - radius * 0.5 - hl, cy - radius * 0.55 - hl, cx - radius * 0.5 + hl, cy - radius * 0.55 + hl], fill=highlight + (255,))
        draw.text((cx - panel_w // 2 + 12, height - 40), animation["name"], fill=(200, 210, 200, 255))
        draw.text((cx - panel_w // 2 + 12, height - 26), f"{animation['frames']}f @ {animation['fps']}fps", fill=(140, 150, 140, 255))

    effect = spec.get("effect")
    if effect:
        draw.text((16, height - 40), f"effect: {effect['id']}", fill=(200, 210, 200, 255))
        draw.text((16, height - 26), f"{effect['frames']}f @ {effect['fps']}fps  {effect['cell']}px", fill=(140, 150, 140, 255))
    return board


def build_env_board(spec):
    width, height = 640, 360
    board = Image.new("RGBA", (width, height), (26, 30, 34, 255))
    draw = ImageDraw.Draw(board)

    draw.text((16, 12), f"{spec['display_name']}  ({spec['id']})", fill=(235, 240, 235, 255))
    draw.text((16, 30), "environment kit board - approve before render", fill=(150, 160, 150, 255))

    y = 60
    for name, component in spec["palette"].items():
        draw.rectangle([16, y, 52, y + 18], fill=rgb(component) + (255,), outline=(70, 76, 70, 255))
        draw.text((60, y + 2), name, fill=(215, 220, 215, 255))
        y += 24

    draw.text((240, 60), f"cell {spec['cell']}px  |  {len(spec['props'])} props", fill=(200, 210, 200, 255))
    x = 240
    yy = 84
    for prop in spec["props"]:
        label = f"{prop['name']}  ({prop.get('archetype', prop['name'])})"
        draw.rectangle([x, yy + 2, x + 8, yy + 10], fill=rgb(spec["palette"].get("leaf", [0.5, 0.6, 0.4])) + (255,))
        draw.text((x + 14, yy), label, fill=(210, 218, 210, 255))
        yy += 20
        if yy > height - 30:
            yy = 84
            x += 200
    return board


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: concept.py <spec.json> <out.png>")
    spec = load_spec(sys.argv[1])
    board = build_env_board(spec) if "props" in spec else build_board(spec)
    board.save(sys.argv[2])
    print(f"CONCEPT_OK {sys.argv[2]}")


if __name__ == "__main__":
    main()
