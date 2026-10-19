extends SceneTree

const KIT_SCRIPT := "res://scripts/world/environment_kit.gd"
const PROP_SCRIPT := "res://scripts/world/prop_sprite.gd"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var atlas_path := ""
	var out_path := ""
	var index := 0
	while index < args.size():
		if args[index] == "--atlas" and index + 1 < args.size():
			atlas_path = args[index + 1]
			index += 2
		elif args[index] == "--out" and index + 1 < args.size():
			out_path = args[index + 1]
			index += 2
		else:
			index += 1
	if atlas_path.is_empty() or out_path.is_empty():
		printerr("build_env_kit: usage --atlas <json> --out <tres>")
		quit(1)
		return
	quit(0 if _build(atlas_path, out_path) else 1)

func _build(atlas_path: String, out_path: String) -> bool:
	var raw := FileAccess.get_file_as_string(atlas_path)
	if raw.is_empty():
		printerr("build_env_kit: cannot read %s" % atlas_path)
		return false
	var data: Variant = JSON.parse_string(raw)
	if data == null or not data is Dictionary:
		printerr("build_env_kit: invalid json in %s" % atlas_path)
		return false
	var atlas: Texture2D = load(String(data.get("image", "")))
	if atlas == null:
		printerr("build_env_kit: atlas texture not imported yet (%s)" % data.get("image", ""))
		return false
	var kit: Resource = load(KIT_SCRIPT).new()
	var cell: Array = data.get("cell", [128, 128])
	kit.cell = Vector2(float(cell[0]), float(cell[1]))
	kit.id = atlas_path.get_file().get_basename()
	var props: Dictionary = data.get("props", {})
	for prop_name: String in props:
		var entry: Dictionary = props[prop_name]
		var region: Array = entry.get("region", [0, 0, cell[0], cell[1]])
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
		var sprite: Resource = load(PROP_SCRIPT).new()
		sprite.texture = texture
		var pivot: Array = entry.get("pivot", [0.0, 0.0])
		sprite.pivot = Vector2(float(pivot[0]), float(pivot[1]))
		sprite.default_scale = float(entry.get("default_scale", 1.0))
		sprite.archetype = StringName(entry.get("archetype", prop_name))
		kit.props[prop_name] = sprite
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var error := ResourceSaver.save(kit, out_path)
	if error != OK:
		printerr("build_env_kit: failed to save %s (error %d)" % [out_path, error])
		return false
	print("build_env_kit: wrote %s (%d props)" % [out_path, kit.props.size()])
	return true
