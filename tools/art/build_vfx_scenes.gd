extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var spec_path := ""
	var out_dir := "res://scenes/effects"
	var index := 0
	while index < args.size():
		if args[index] == "--spec" and index + 1 < args.size():
			spec_path = args[index + 1]
			index += 2
		elif args[index] == "--out-dir" and index + 1 < args.size():
			out_dir = args[index + 1]
			index += 2
		else:
			index += 1
	if spec_path.is_empty():
		printerr("build_vfx_scenes: usage --spec <json> [--out-dir <dir>]")
		quit(1)
		return
	var raw := FileAccess.get_file_as_string(spec_path)
	var spec: Variant = JSON.parse_string(raw)
	if spec == null or not spec is Dictionary:
		printerr("build_vfx_scenes: cannot read spec %s" % spec_path)
		quit(1)
		return
	var id := String(spec.get("id", ""))
	var frames_path := "res://data/visuals/%s_vfx_frames.tres" % id
	var written := 0
	for effect: Dictionary in spec.get("effects", []):
		var effect_id := String(effect.get("id", ""))
		if effect_id.is_empty():
			continue
		if _write_scene(out_dir, effect_id, frames_path):
			written += 1
	print("build_vfx_scenes: wrote %d scenes for %s" % [written, id])
	quit(0)

func _write_scene(out_dir: String, effect_id: String, frames_path: String) -> bool:
	var text := "\n".join([
		"[gd_scene load_steps=3 format=3]",
		"",
		"[ext_resource type=\"Script\" path=\"res://scripts/effects/sprite_effect.gd\" id=\"1_effect\"]",
		"[ext_resource type=\"SpriteFrames\" path=\"%s\" id=\"2_frames\"]" % frames_path,
		"",
		"[node name=\"%s\" type=\"AnimatedSprite2D\"]" % effect_id,
		"script = ExtResource(\"1_effect\")",
		"frames = ExtResource(\"2_frames\")",
		"autoplay_animation = &\"%s\"" % effect_id,
		"",
	])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path := out_dir.path_join("%s.tscn" % effect_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("build_vfx_scenes: cannot write %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true
