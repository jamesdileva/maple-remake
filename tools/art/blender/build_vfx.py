"""Agent-assisted Blender stage of the class-VFX pipeline.

Reads a class VFX spec, procedurally builds each effect frame by frame from
primitives (all billboarded in the camera plane so it reads like 2D art) and
renders transparent PNGs. Effects are shared archetypes parameterised by a
per-class palette.

Usage:
    blender --background --python tools/art/blender/build_vfx.py -- \
        --spec tools/art/vfx_specs/mage.json --out art_src/vfx/mage

Writes:
    <out>/manifest.json
    <out>/<effect_id>/<effect_id>_####.png
"""

import json
import math
import os
import sys

import bpy

DEFAULT_PALETTE = {
    "glow": [0.6, 0.8, 1.0],
    "core": [0.9, 0.85, 1.0],
    "accent": [0.4, 0.6, 1.0],
    "dark": [0.22, 0.25, 0.5],
}

TAU = math.pi * 2.0
CENTER_Z = 0.0


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
        raise SystemExit("build_vfx.py requires --spec and --out")
    return spec_path, out_dir


def load_spec(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def deselect_all():
    bpy.ops.object.select_all(action="DESELECT")


def make_material(name, color):
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
        material.use_nodes = False
    material.diffuse_color = (color[0], color[1], color[2], 1.0)
    return material


def spawn(kind, size, offset, material, rotation=(0.0, 0.0, 0.0)):
    deselect_all()
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=offset)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=1.0, depth=1.0, location=offset)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.0, radius2=0.0, depth=1.0, location=offset)
    elif kind == "ico":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=offset)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=1.0, location=offset)
    obj = bpy.context.object
    obj.rotation_euler = (math.radians(rotation[0]), math.radians(rotation[1]), math.radians(rotation[2]))
    obj.scale = (max(0.001, size[0]), max(0.001, size[1]), max(0.001, size[2]))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(material)
    return obj


def join(objects, name):
    deselect_all()
    if not objects:
        return None
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    return joined


def ring(count, radius, size, material, phase=0.0, arc=TAU, start=0.0, scale_z=1.0):
    objects = []
    for index in range(count):
        angle = start + phase + arc * (float(index) / float(count))
        objects.append(spawn(
            "cube",
            (size, size, size * scale_z),
            (math.cos(angle) * radius, 0.0, math.sin(angle) * radius),
            material,
            (0.0, 0.0, math.degrees(angle)),
        ))
    return objects


def outward_shards(count, radius, length, thickness, material, phase=0.0):
    objects = []
    for index in range(count):
        angle = phase + TAU * (float(index) / float(count))
        x = math.cos(angle) * radius
        z = math.sin(angle) * radius
        objects.append(spawn(
            "cone",
            (thickness, thickness, length),
            (x, 0.0, z),
            material,
            (0.0, math.degrees(angle) - 90.0, 0.0),
        ))
    return objects


def build_frame(kind, materials, progress):
    p = max(0.0, min(1.0, progress))
    glow = materials["glow"]
    core = materials["core"]
    accent = materials["accent"]
    dark = materials["dark"]
    parts = []

    if kind == "sigil":
        grow = 0.9 + 0.1 * math.sin(p * TAU)
        parts += ring(16, 0.55 * grow, 0.06, glow, phase=p * TAU * 0.25)
        parts += ring(12, 0.38 * grow, 0.045, accent, phase=-p * TAU * 0.4)
        parts.append(spawn("sph", (0.10 + 0.02 * math.sin(p * TAU),) * 3, (0.0, 0.0, CENTER_Z), core))
    elif kind == "arcane_burst":
        radius = 0.12 + 0.6 * p
        parts += ring(6, radius, max(0.015, 0.09 * (1.0 - p)), glow, phase=p * 1.2)
        parts += outward_shards(8, radius * 0.9, max(0.02, 0.20 * (1.0 - p)), 0.05, accent, phase=p * 0.6)
        parts.append(spawn("sph", ((0.16 * (1.0 - p)) + 0.03,) * 3, (0.0, 0.0, CENTER_Z), core))
    elif kind == "charge":
        radius = 0.9 - 0.6 * min(1.0, p * 1.15)
        parts += ring(12, radius, 0.05, accent, phase=p * TAU * 0.5)
        parts += ring(8, radius + 0.16, 0.04, glow, phase=-p * TAU * 0.3)
        for index in range(6):
            angle = TAU * (float(index) / 6.0)
            parts.append(spawn(
                "cube",
                (0.05, 0.05, 0.05),
                (math.cos(angle) * 0.3, 0.0, -0.3 + 0.32 * p),
                dark,
            ))
    elif kind == "quake_impact":
        for index in range(8):
            angle = TAU * (float(index) / 8.0)
            parts.append(spawn(
                "ico",
                (0.12 * (1.0 - 0.5 * p),) * 3,
                (math.cos(angle) * 0.42, math.sin(angle) * 0.22, -0.45 + 0.8 * p),
                accent,
            ))
        parts += ring(12, 0.2 + 0.5 * p, max(0.01, 0.05 * (1.0 - p)), glow, start=0.0, scale_z=0.35)
    elif kind == "reticle":
        dist = 0.7 - 0.4 * p
        for sign_x in (-1.0, 1.0):
            for sign_z in (-1.0, 1.0):
                parts.append(spawn("cube", (0.18, 0.05, 0.05), (sign_x * dist, 0.0, sign_z * dist), glow))
                parts.append(spawn("cube", (0.05, 0.05, 0.18), (sign_x * dist, 0.0, sign_z * dist), glow))
        span = 0.24 * (1.0 - 0.4 * p)
        parts.append(spawn("cube", (span, 0.04, 0.03), (0.0, 0.0, 0.0), accent))
        parts.append(spawn("cube", (0.03, 0.04, span), (0.0, 0.0, 0.0), accent))
    elif kind == "bolt_impact":
        radius = 0.1 + 0.4 * p
        parts.append(spawn("sph", ((0.12 * (1.0 - p)) + 0.02,) * 3, (0.0, 0.0, CENTER_Z), core))
        parts += outward_shards(6, radius, max(0.02, 0.16 * (1.0 - p)), 0.045, glow, phase=p * 0.4)
        parts += ring(10, radius * 1.1, max(0.01, 0.04 * (1.0 - p)), accent)
    elif kind == "shroud":
        parts.append(spawn("sph", (0.10,) * 3, (0.0, 0.0, CENTER_Z), dark))
        parts += ring(5, 0.35, 0.04, glow, phase=p * TAU, scale_z=8.0)
        parts += ring(8, 0.5, max(0.01, 0.04 * (1.0 - p)), accent, phase=-p * TAU * 1.5)
    elif kind == "edge":
        sweep = -0.95 + 1.9 * p
        for index in range(7):
            offset = (index - 3) * 0.11
            angle = sweep + offset
            taper = 0.13 * (1.0 - abs(index - 3) / 3.6)
            parts.append(spawn(
                "cube",
                (max(0.02, taper), 0.05, 0.09 + taper),
                (math.cos(angle) * 0.6, 0.0, math.sin(angle) * 0.6),
                glow,
                (0.0, 0.0, math.degrees(angle)),
            ))
        parts.append(spawn("sph", (0.05,) * 3, (0.0, 0.0, CENTER_Z), core))
    else:
        parts.append(spawn("sph", (0.12,) * 3, (0.0, 0.0, CENTER_Z), glow))

    return join(parts, "Frame")


def setup_scene(cell, view):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = False
    shading.show_cavity = False
    shading.show_object_outline = False
    scene.render.film_transparent = True
    scene.render.resolution_x = cell
    scene.render.resolution_y = cell
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    camera_data = bpy.data.cameras.new("Cam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = view
    camera = bpy.data.objects.new("Cam", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0.0, -6.0, CENTER_Z)
    camera.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = camera
    return scene


def clear_meshes():
    deselect_all()
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)


def main():
    spec_path, out_dir = parse_args()
    spec = load_spec(spec_path)
    spec["palette"] = dict(DEFAULT_PALETTE, **spec.get("palette", {}))
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)

    cell = int(spec["cell"])
    view = float(spec.get("view", 1.8))
    scene = setup_scene(cell, view)
    materials = {}
    for key, color in spec["palette"].items():
        materials[key] = make_material("mat_" + key, color)

    manifest = {"id": spec["id"], "display_name": spec["display_name"], "kind": "vfx", "cell": [cell, cell], "view": view}
    effects = {}
    for effect in spec["effects"]:
        effect_id = effect["id"]
        kind = effect.get("kind", effect_id)
        frames = int(effect["frames"])
        loop = bool(effect.get("loop", False))
        directory = os.path.join(out_dir, effect_id)
        os.makedirs(directory, exist_ok=True)
        files = []
        for frame in range(1, frames + 1):
            progress = (float(frame) / float(frames)) if loop else (float(frame - 1) / float(max(1, frames - 1)))
            clear_meshes()
            build_frame(kind, materials, progress)
            path = os.path.join(directory, "%s_%04d.png" % (effect_id, frame))
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            files.append(os.path.relpath(path, out_dir).replace("\\", "/"))
        effects[effect_id] = {"cell": [cell, cell], "fps": effect["fps"], "loop": loop, "count": frames, "files": files}
    manifest["effects"] = effects

    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)

    print("BLENDER_OK %s" % os.path.join(out_dir, "manifest.json"))


if __name__ == "__main__":
    main()
