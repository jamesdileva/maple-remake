extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var pairs: Array = []
	var index := 0
	while index < args.size():
		if args[index] == "--atlas" and index + 1 < args.size():
			pairs.append([args[index + 1], ""])
			index += 2
		elif args[index] == "--out" and index + 1 < args.size() and not pairs.is_empty():
			pairs[pairs.size() - 1][1] = args[index + 1]
			index += 2
		else:
			index += 1
	if pairs.is_empty():
		printerr("build_spriteframes: no --atlas/--out pairs given")
		quit(1)
		return
	var failures := 0
	for pair: Array in pairs:
		if not _build(pair[0], pair[1]):
			failures += 1
	print("SPRITEFRAMES_RESULT %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)

func _build(atlas_path: String, out_path: String) -> bool:
	if out_path.is_empty():
		printerr("build_spriteframes: missing --out for %s" % atlas_path)
		return false
	var raw := FileAccess.get_file_as_string(atlas_path)
	if raw.is_empty():
		printerr("build_spriteframes: cannot read %s" % atlas_path)
		return false
	var data: Variant = JSON.parse_string(raw)
	if data == null or not data is Dictionary:
		printerr("build_spriteframes: invalid json in %s" % atlas_path)
		return false
	var atlas: Texture2D = load(String(data.get("image", "")))
	if atlas == null:
		printerr("build_spriteframes: atlas texture not imported yet (%s)" % data.get("image", ""))
		return false
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var animations: Dictionary = data.get("animations", {})
	for name: String in animations:
		var entry: Dictionary = animations[name]
		frames.add_animation(name)
		frames.set_animation_speed(name, float(entry.get("fps", 8.0)))
		frames.set_animation_loop(name, bool(entry.get("loop", false)))
		for region: Array in entry.get("frames", []):
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
			frames.add_frame(name, frame, 1.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var error := ResourceSaver.save(frames, out_path)
	if error != OK:
		printerr("build_spriteframes: failed to save %s (error %d)" % [out_path, error])
		return false
	var debug: Node = root.get_node_or_null("DebugManager")
	if debug != null and debug.has_method("register_combat_event"):
		debug.register_combat_event("art_export", {"atlas": atlas_path, "frames": out_path, "animations": animations.size()})
	print("build_spriteframes: wrote %s (%d animations)" % [out_path, animations.size()])
	return true
