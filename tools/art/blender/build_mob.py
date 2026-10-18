"""Agent-assisted Blender stage of the art pipeline.

Reads a mob spec, procedurally builds a rigged, animated slime and renders
transparent PNG sprite frames for every animation, plus the attack effect
frames. No manual Blender steps: the pipeline runs this headless.

Usage:
    blender --background --python tools/art/blender/build_mob.py -- \
        --spec tools/art/specs/meadow_slime.json --out art_src/meadow_slime

Writes:
    <out>/manifest.json
    <out>/mob/<anim>/<anim>_####.png
    <out>/effect/<effect_id>/<effect_id>_####.png
"""

import json
import math
import os
import sys

import bpy


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
        raise SystemExit("build_mob.py requires --spec and --out")
    return spec_path, out_dir


def load_spec(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def deselect_all():
    bpy.ops.object.select_all(action="DESELECT")


def make_material(name, color):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (color[0], color[1], color[2], 1.0)
    material.use_nodes = False
    return material


def add_sphere(radius, location, material, scale=(1.0, 1.0, 1.0), segments=32, rings=16):
    deselect_all()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
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


def build_slime(spec):
    palette = spec["palette"]
    shape = spec["shape"]
    radius = shape["radius"]
    squash = shape["squash"]
    center_z = radius * (1.0 - squash)
    body = add_sphere(radius, (0.0, 0.0, center_z), make_material("Body", palette["body"]), scale=(1.0, 1.0, 1.0 - squash))
    eye_material = make_material("Eye", palette["eye"])
    eye_size = shape["eye_size"]
    eye_spacing = shape["eye_spacing"]
    eye_z = center_z + radius * 0.18
    eyes = []
    for sign in (-1.0, 1.0):
        eyes.append(add_sphere(eye_size, (sign * eye_spacing, -(radius * 0.82), eye_z), eye_material, segments=16, rings=8))
    highlight = add_sphere(
        shape["highlight_size"],
        (-radius * 0.42, -(radius * 0.70), center_z + radius * 0.40),
        make_material("Highlight", palette["highlight"]),
        segments=16,
        rings=8,
    )
    return join([body] + eyes + [highlight], "SlimeMesh")


def build_rig(mesh, radius):
    deselect_all()
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    armature = bpy.context.object
    armature.name = "SlimeRig"
    root = armature.data.edit_bones[0]
    root.name = "root"
    root.head = (0.0, 0.0, 0.0)
    root.tail = (0.0, 0.0, radius * 1.8)
    bpy.ops.object.mode_set(mode="OBJECT")
    group = mesh.vertex_groups.new(name="root")
    group.add([vertex.index for vertex in mesh.data.vertices], 1.0, "REPLACE")
    modifier = mesh.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature
    mesh.parent = armature
    return armature


def setup_scene(cell, ortho_scale=1.2, center_z=0.45):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = False
    shading.show_cavity = False
    shading.show_object_outline = True
    shading.object_outline_color = (0.12, 0.18, 0.10)
    scene.render.film_transparent = True
    scene.render.resolution_x = cell
    scene.render.resolution_y = cell
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    camera_data = bpy.data.cameras.new("Cam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = ortho_scale
    camera = bpy.data.objects.new("Cam", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0.0, -6.0, center_z)
    camera.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = camera
    return scene


def sample(curve, t):
    if t <= curve[0][0]:
        return curve[0][1:]
    if t >= curve[-1][0]:
        return curve[-1][1:]
    for index in range(len(curve) - 1):
        left = curve[index]
        right = curve[index + 1]
        if left[0] <= t <= right[0]:
            span = right[0] - left[0]
            blend = 0.0 if span <= 0.0 else (t - left[0]) / span
            return tuple(left[key] + (right[key] - left[key]) * blend for key in range(1, len(left)))
    return curve[-1][1:]


def key_pose(bone, frame, pose):
    horizontal, vertical, offset_x, offset_y, rotation_z = pose
    bone.scale = (horizontal, vertical, horizontal)
    bone.location = (offset_x, offset_y, 0.0)
    bone.rotation_mode = "XYZ"
    bone.rotation_euler = (0.0, 0.0, rotation_z)
    bone.keyframe_insert("scale", frame=frame)
    bone.keyframe_insert("location", frame=frame)
    bone.keyframe_insert("rotation_euler", frame=frame)


def render_mob(scene, armature, spec, out_dir, manifest):
    bone = armature.pose.bones["root"]
    curves = spec["curves"]
    animations = {}
    for animation in spec["animations"]:
        name = animation["name"]
        frames = int(animation["frames"])
        loop = bool(animation["loop"])
        curve = curves[name]
        directory = os.path.join(out_dir, "mob", name)
        os.makedirs(directory, exist_ok=True)
        for frame in range(1, frames + 1):
            t = (frame / float(frames)) if loop else ((frame - 1) / float(max(1, frames - 1)))
            key_pose(bone, frame, sample(curve, t))
        scene.frame_start = 1
        scene.frame_end = frames
        files = []
        for frame in range(1, frames + 1):
            scene.frame_set(frame)
            path = os.path.join(directory, "%s_%04d.png" % (name, frame))
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            files.append(os.path.relpath(path, out_dir).replace("\\", "/"))
        animations[name] = {"fps": animation["fps"], "loop": loop, "count": frames, "files": files}
    manifest["animations"] = animations


def build_splash(spec, progress):
    goo = make_material("Goo", spec["palette"]["goo"])
    highlight = make_material("SplashHighlight", spec["palette"]["highlight"])
    disc_radius = 0.10 + 0.22 * min(1.0, progress * 1.4)
    if progress > 0.72:
        disc_radius *= max(0.0, 1.0 - (progress - 0.72) / 0.28)
    parts = [add_sphere(max(0.001, disc_radius), (0.0, 0.0, 0.05), goo, scale=(1.0, 1.0, 0.32))]
    droplets = 6
    for index in range(droplets):
        angle = (math.pi * 2.0 / droplets) * index
        spread = 0.16 + 0.26 * progress
        rise = math.sin(min(1.0, progress * 1.2) * math.pi) * 0.24
        size = max(0.001, 0.055 * (1.0 - progress * 0.7))
        parts.append(add_sphere(size, (math.cos(angle) * spread, math.sin(angle) * spread * 0.4 + 0.02, 0.10 + rise), highlight))
    return join(parts, "Splash")


def render_effect(scene, spec, out_dir, manifest):
    effect = spec.get("effect")
    if not effect:
        manifest["effects"] = {}
        return
    effect_id = effect["id"]
    frames = int(effect["frames"])
    directory = os.path.join(out_dir, "effect", effect_id)
    os.makedirs(directory, exist_ok=True)
    files = []
    for frame in range(1, frames + 1):
        deselect_all()
        for obj in list(bpy.data.objects):
            if obj.type == "MESH":
                bpy.data.objects.remove(obj, do_unlink=True)
        build_splash(spec, (frame - 1) / float(max(1, frames - 1)))
        scene.frame_set(frame)
        path = os.path.join(directory, "%s_%04d.png" % (effect_id, frame))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        files.append(os.path.relpath(path, out_dir).replace("\\", "/"))
    manifest["effects"] = {
        effect_id: {"cell": [int(effect["cell"]), int(effect["cell"])], "fps": effect["fps"], "count": frames, "files": files}
    }


def main():
    spec_path, out_dir = parse_args()
    spec = load_spec(spec_path)
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)

    reset_scene()
    mesh = build_slime(spec)
    radius = spec["shape"]["radius"]
    armature = build_rig(mesh, radius)

    cell = int(spec["cell"])
    scene = setup_scene(cell)

    manifest = {"id": spec["id"], "display_name": spec["display_name"], "cell": [cell, cell]}
    render_mob(scene, armature, spec, out_dir, manifest)

    effect_cell = int(spec.get("effect", {}).get("cell", cell))
    effect_scene = setup_scene(effect_cell, ortho_scale=0.9, center_z=0.28)
    render_effect(effect_scene, spec, out_dir, manifest)

    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)

    print("BLENDER_OK %s" % os.path.join(out_dir, "manifest.json"))


if __name__ == "__main__":
    main()
