"""Agent-assisted Blender stage of the environment pipeline.

Reads a region kit spec, procedurally builds each reusable prop archetype from
primitives, and renders one transparent PNG per prop. Kits vary by palette and
prop selection only: archetypes are shared across every region (reuse-first).

Usage:
    blender --background --python tools/art/blender/build_env.py -- \
        --spec tools/art/env_specs/sunlit_meadow.json --out art_src/env/sunlit_meadow

Writes:
    <out>/manifest.json
    <out>/props/<name>.png
"""

import json
import math
import os
import sys

import bpy

DEFAULT_PALETTE = {
    "trunk": [0.4, 0.3, 0.2],
    "leaf": [0.4, 0.6, 0.32],
    "leaf_dark": [0.3, 0.48, 0.26],
    "rock": [0.55, 0.55, 0.52],
    "rock_dark": [0.42, 0.42, 0.4],
    "wood": [0.55, 0.38, 0.22],
    "stone": [0.62, 0.6, 0.55],
    "cloth": [0.7, 0.35, 0.3],
    "metal": [0.46, 0.46, 0.5],
    "glow": [1.0, 0.85, 0.45],
    "flower": [0.95, 0.65, 0.75],
    "cap": [0.85, 0.55, 0.45],
    "accent": [0.7, 0.66, 0.5],
}

# Each primitive: (kind, size, offset, material, rotation_degrees)
#   kind: cube | cyl | cone | sph | ico
#   cube size = full extents; sph/ico size = radius; cyl/cone size = (rx, ry, height)
# Ground sits at z = 0 so every prop's feet rest on the placement point.
ARCHETYPES = {
    "tree": [
        ("cyl", (0.05, 0.05, 0.44), (0, 0, 0.22), "trunk", (0, 0, 0)),
        ("sph", (0.22, 0.22, 0.20), (0, 0, 0.60), "leaf", (0, 0, 0)),
        ("sph", (0.15, 0.15, 0.14), (-0.13, 0.02, 0.52), "leaf_dark", (0, 0, 0)),
        ("sph", (0.14, 0.14, 0.13), (0.12, -0.02, 0.44), "leaf", (0, 0, 0)),
    ],
    "dead_tree": [
        ("cyl", (0.05, 0.05, 0.58), (0, 0, 0.29), "trunk", (0, 0, 0)),
        ("cyl", (0.028, 0.028, 0.28), (-0.11, 0, 0.65), "trunk", (0, 40, 0)),
        ("cyl", (0.024, 0.024, 0.24), (0.10, 0, 0.56), "trunk", (0, -50, 0)),
        ("cyl", (0.02, 0.02, 0.18), (0.02, 0, 0.74), "trunk", (0, -18, 0)),
    ],
    "bush": [
        ("sph", (0.20, 0.20, 0.16), (0, 0, 0.15), "leaf", (0, 0, 0)),
        ("sph", (0.14, 0.14, 0.12), (-0.14, 0, 0.13), "leaf_dark", (0, 0, 0)),
        ("sph", (0.13, 0.13, 0.11), (0.13, 0.01, 0.12), "leaf", (0, 0, 0)),
    ],
    "rock": [
        ("ico", (0.20, 0.16, 0.13), (0, 0, 0.10), "rock", (0, 0, 0)),
        ("ico", (0.10, 0.09, 0.08), (-0.16, 0.02, 0.05), "rock_dark", (0, 0, 0)),
    ],
    "grass": [
        ("cone", (0.05, 0.05, 0.22), (0, 0, 0.11), "leaf", (0, 0, 0)),
        ("cone", (0.04, 0.04, 0.18), (-0.08, 0.02, 0.09), "leaf_dark", (0, 0, 0)),
        ("cone", (0.04, 0.04, 0.21), (0.07, -0.02, 0.10), "leaf", (0, 0, 0)),
    ],
    "flower": [
        ("cyl", (0.012, 0.012, 0.18), (0, 0, 0.09), "leaf", (0, 0, 0)),
        ("sph", (0.05, 0.05, 0.04), (0, 0, 0.20), "flower", (0, 0, 0)),
        ("sph", (0.028, 0.028, 0.028), (0, 0, 0.20), "glow", (0, 0, 0)),
    ],
    "mushroom": [
        ("cyl", (0.035, 0.035, 0.11), (0, 0, 0.055), "trunk", (0, 0, 0)),
        ("sph", (0.11, 0.11, 0.07), (0, 0, 0.12), "cap", (0, 0, 0)),
        ("sph", (0.05, 0.05, 0.03), (-0.06, 0.03, 0.14), "cap", (0, 0, 0)),
        ("sph", (0.03, 0.03, 0.02), (0.06, -0.02, 0.13), "glow", (0, 0, 0)),
    ],
    "fern": [
        ("cyl", (0.015, 0.015, 0.30), (0, 0, 0.15), "leaf", (0, 28, 0)),
        ("cyl", (0.015, 0.015, 0.30), (0, 0, 0.15), "leaf", (0, -28, 0)),
        ("cyl", (0.014, 0.014, 0.26), (0, 0, 0.13), "leaf_dark", (22, 0, 0)),
        ("cyl", (0.014, 0.014, 0.26), (0, 0, 0.13), "leaf_dark", (-22, 0, 0)),
    ],
    "crystal": [
        ("ico", (0.16, 0.14, 0.06), (0, 0, 0.03), "rock", (0, 0, 0)),
        ("cone", (0.06, 0.06, 0.32), (0, 0, 0.16), "glow", (0, 0, 0)),
        ("cone", (0.05, 0.05, 0.22), (-0.09, 0.02, 0.11), "accent", (0, 20, 0)),
        ("cone", (0.04, 0.04, 0.18), (0.08, -0.02, 0.09), "accent", (0, -16, 0)),
    ],
    "ore": [
        ("ico", (0.20, 0.17, 0.14), (0, 0, 0.10), "rock", (0, 0, 0)),
        ("cone", (0.05, 0.05, 0.16), (0.05, 0.02, 0.22), "glow", (0, 0, 0)),
        ("cone", (0.04, 0.04, 0.12), (-0.07, -0.02, 0.17), "accent", (0, 0, 0)),
    ],
    "pillar": [
        ("cube", (0.30, 0.30, 0.07), (0, 0, 0.035), "stone", (0, 0, 0)),
        ("cyl", (0.09, 0.09, 0.52), (0, 0, 0.30), "stone", (0, 0, 0)),
        ("cube", (0.26, 0.26, 0.08), (0, 0, 0.60), "stone", (0, 0, 0)),
    ],
    "broken_pillar": [
        ("cube", (0.30, 0.30, 0.07), (0, 0, 0.035), "stone", (0, 0, 0)),
        ("cyl", (0.09, 0.09, 0.30), (0, 0, 0.20), "stone", (0, 0, 0)),
        ("cube", (0.22, 0.22, 0.06), (0.02, 0, 0.37), "stone", (12, 6, 0)),
    ],
    "crate": [
        ("cube", (0.30, 0.30, 0.30), (0, 0, 0.15), "wood", (0, 0, 0)),
        ("cube", (0.32, 0.32, 0.05), (0, 0, 0.27), "trunk", (0, 0, 0)),
    ],
    "barrel": [
        ("cyl", (0.15, 0.15, 0.34), (0, 0, 0.17), "wood", (0, 0, 0)),
        ("cyl", (0.16, 0.16, 0.03), (0, 0, 0.06), "metal", (0, 0, 0)),
        ("cyl", (0.16, 0.16, 0.03), (0, 0, 0.28), "metal", (0, 0, 0)),
    ],
    "lantern": [
        ("cyl", (0.02, 0.02, 0.62), (0, 0, 0.31), "metal", (0, 0, 0)),
        ("cube", (0.13, 0.13, 0.14), (0, 0, 0.70), "glow", (0, 0, 0)),
        ("cube", (0.16, 0.16, 0.04), (0, 0, 0.79), "metal", (0, 0, 0)),
    ],
    "building": [
        ("cube", (0.80, 0.60, 0.58), (0, 0, 0.29), "stone", (0, 0, 0)),
        ("cone", (0.60, 0.46, 0.34), (0, 0, 0.75), "cloth", (0, 0, 0)),
        ("cube", (0.16, 0.06, 0.24), (0, -0.31, 0.12), "trunk", (0, 0, 0)),
        ("cube", (0.12, 0.05, 0.12), (-0.24, -0.31, 0.42), "glow", (0, 0, 0)),
        ("cube", (0.12, 0.05, 0.12), (0.24, -0.31, 0.42), "glow", (0, 0, 0)),
    ],
    "sign": [
        ("cyl", (0.02, 0.02, 0.40), (0, 0, 0.20), "wood", (0, 0, 0)),
        ("cube", (0.32, 0.05, 0.18), (0, 0, 0.45), "wood", (0, 0, 0)),
        ("cube", (0.26, 0.06, 0.04), (0, 0, 0.49), "cloth", (0, 0, 0)),
    ],
    "beam": [
        ("cube", (0.08, 0.08, 0.62), (-0.26, 0, 0.31), "wood", (0, 0, 0)),
        ("cube", (0.08, 0.08, 0.62), (0.26, 0, 0.31), "wood", (0, 0, 0)),
        ("cube", (0.64, 0.10, 0.09), (0, 0, 0.63), "wood", (0, 0, 0)),
    ],
    "cart": [
        ("cube", (0.38, 0.24, 0.18), (0, 0, 0.24), "wood", (0, 0, 0)),
        ("cyl", (0.09, 0.09, 0.04), (-0.12, 0.13, 0.09), "metal", (90, 0, 0)),
        ("cyl", (0.09, 0.09, 0.04), (0.12, 0.13, 0.09), "metal", (90, 0, 0)),
        ("ico", (0.15, 0.10, 0.08), (0, 0, 0.36), "rock", (0, 0, 0)),
    ],
    "torch": [
        ("cyl", (0.02, 0.02, 0.52), (0, 0, 0.26), "wood", (0, 0, 0)),
        ("sph", (0.07, 0.07, 0.10), (0, 0, 0.58), "glow", (0, 0, 0)),
        ("sph", (0.04, 0.04, 0.06), (0, 0, 0.66), "accent", (0, 0, 0)),
    ],
    "battlement": [
        ("cube", (0.62, 0.30, 0.42), (0, 0, 0.21), "stone", (0, 0, 0)),
        ("cube", (0.12, 0.30, 0.16), (-0.24, 0, 0.50), "stone", (0, 0, 0)),
        ("cube", (0.12, 0.30, 0.16), (0.0, 0, 0.50), "stone", (0, 0, 0)),
        ("cube", (0.12, 0.30, 0.16), (0.24, 0, 0.50), "stone", (0, 0, 0)),
    ],
    "spike": [
        ("cone", (0.06, 0.06, 0.38), (0, 0, 0.19), "metal", (0, 0, 0)),
        ("cone", (0.06, 0.06, 0.30), (-0.11, 0.04, 0.15), "metal", (0, 0, 0)),
        ("cone", (0.05, 0.05, 0.26), (0.10, -0.03, 0.13), "metal", (0, 0, 0)),
    ],
    "banner": [
        ("cyl", (0.02, 0.02, 0.72), (0, 0, 0.36), "wood", (0, 0, 0)),
        ("cube", (0.26, 0.03, 0.42), (0.13, 0, 0.53), "cloth", (0, 0, 0)),
        ("cube", (0.28, 0.04, 0.06), (0.13, 0, 0.70), "metal", (0, 0, 0)),
    ],
    "rubble": [
        ("ico", (0.14, 0.12, 0.08), (0, 0, 0.06), "stone", (0, 0, 0)),
        ("ico", (0.09, 0.08, 0.07), (-0.15, 0.02, 0.05), "rock_dark", (0, 0, 0)),
        ("ico", (0.07, 0.07, 0.06), (0.13, -0.03, 0.05), "stone", (0, 0, 0)),
    ],
    "altar": [
        ("cube", (0.40, 0.30, 0.20), (0, 0, 0.10), "stone", (0, 0, 0)),
        ("cube", (0.46, 0.34, 0.05), (0, 0, 0.23), "stone", (0, 0, 0)),
        ("cone", (0.08, 0.08, 0.30), (0, 0, 0.40), "glow", (0, 0, 0)),
    ],
    "tentacle": [
        ("cyl", (0.07, 0.07, 0.52), (0, 0, 0.26), "leaf_dark", (0, 0, 0)),
        ("cyl", (0.05, 0.05, 0.34), (0.10, 0, 0.46), "leaf_dark", (0, -32, 0)),
        ("cyl", (0.04, 0.04, 0.26), (-0.10, 0, 0.40), "leaf_dark", (0, 36, 0)),
        ("sph", (0.07, 0.07, 0.07), (0, 0, 0.55), "accent", (0, 0, 0)),
    ],
}


def parse_args():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    spec_path = None
    out_dir = None
    index = 0
    while index < len(args):
        if args[index] == "--spec" and index + 1 < len(args):
            spec_path = args[index + 1]
            index += 2
        elif args[index] == "--out" and index + 1 < len(args):
            out_dir = args[index + 1]
            index += 2
        else:
            index += 1
    if spec_path is None or out_dir is None:
        raise SystemExit("build_env.py requires --spec and --out")
    return spec_path, out_dir


def load_spec(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def deselect_all():
    bpy.ops.object.select_all(action="DESELECT")


def make_material(name, color):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (color[0], color[1], color[2], 1.0)
    material.use_nodes = False
    return material


def build_materials(palette):
    materials = {}
    for key, color in palette.items():
        materials[key] = make_material("mat_" + key, color)
    return materials


def spawn(kind, size, offset, material, rotation):
    deselect_all()
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=offset)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.0, depth=1.0, location=offset)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=1.0, radius2=0.0, depth=1.0, location=offset)
    elif kind == "ico":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=offset)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0, location=offset)
    obj = bpy.context.object
    obj.rotation_euler = (math.radians(rotation[0]), math.radians(rotation[1]), math.radians(rotation[2]))
    obj.scale = (size[0], size[1], size[2])
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(material)
    return obj


def join(objects, name):
    deselect_all()
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    return joined


def build_prop(archetype, materials):
    parts = []
    for kind, size, offset, material_key, rotation in archetype:
        parts.append(spawn(kind, size, offset, materials[material_key], rotation))
    return join(parts, "Prop")


def world_bounds(obj):
    coordinates = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    xs = [coordinate.x for coordinate in coordinates]
    ys = [coordinate.y for coordinate in coordinates]
    zs = [coordinate.z for coordinate in coordinates]
    return (min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs))


def setup_scene(cell):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = False
    shading.show_cavity = False
    shading.show_object_outline = True
    shading.object_outline_color = (0.12, 0.15, 0.12)
    scene.render.film_transparent = True
    scene.render.resolution_x = cell
    scene.render.resolution_y = cell
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    camera_data = bpy.data.cameras.new("Cam")
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new("Cam", camera_data)
    scene.collection.objects.link(camera)
    camera.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = camera
    return scene, camera


def clear_meshes():
    deselect_all()
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)


def render_props(spec, out_dir, manifest):
    cell = int(spec["cell"])
    scene, camera = setup_scene(cell)
    materials = build_materials(spec["palette"])
    directory = os.path.join(out_dir, "props")
    os.makedirs(directory, exist_ok=True)

    props = {}
    for entry in spec["props"]:
        name = entry["name"]
        archetype_name = entry.get("archetype", name)
        if archetype_name not in ARCHETYPES:
            raise SystemExit("build_env.py: unknown archetype '%s' for prop '%s'" % (archetype_name, name))
        clear_meshes()
        prop = build_prop(ARCHETYPES[archetype_name], materials)
        (min_x, max_x), (_, _), (min_z, max_z) = world_bounds(prop)
        width = max(0.001, max_x - min_x)
        height = max(0.001, max_z - min_z)
        ortho_scale = max(width, height) * 1.2
        center_x = (min_x + max_x) * 0.5
        center_z = (min_z + max_z) * 0.5
        camera.data.ortho_scale = ortho_scale
        camera.location = (center_x, -6.0, center_z)
        # Ground contact (bottom-center of the bbox) in pixels, measured from the
        # cell center, y-down, so the runtime can anchor the sprite at its feet.
        pivot_y = (center_z - min_z) / ortho_scale * float(cell)
        path = os.path.join(directory, name + ".png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        props[name] = {
            "file": os.path.relpath(path, out_dir).replace("\\", "/"),
            "archetype": archetype_name,
            "pivot": [0.0, round(pivot_y, 3)],
            "default_scale": float(entry.get("scale", 1.0)),
        }

    manifest["cell"] = [cell, cell]
    manifest["props"] = props


def main():
    spec_path, out_dir = parse_args()
    spec = load_spec(spec_path)
    spec["palette"] = dict(DEFAULT_PALETTE, **spec.get("palette", {}))
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)

    manifest = {"id": spec["id"], "display_name": spec["display_name"], "kind": "environment"}
    render_props(spec, out_dir, manifest)

    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)

    print("BLENDER_OK %s" % os.path.join(out_dir, "manifest.json"))


if __name__ == "__main__":
    main()
