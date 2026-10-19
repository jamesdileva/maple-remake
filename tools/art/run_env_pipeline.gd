extends SceneTree

const PYTHON := "python"
const BLENDER_CANDIDATES := [
	"C:/Program Files/Blender Foundation/Blender 5.1/blender.exe",
	"C:/Program Files/Blender Foundation/Blender 5.0/blender.exe",
	"C:/Program Files/Blender Foundation/Blender 4.3/blender.exe",
]

func _initialize() -> void:
	_run()

func _run() -> void:
	var id := "sunlit_meadow"
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		if args[index] == "--kit" and index + 1 < args.size():
			id = args[index + 1]
			index += 2
		else:
			index += 1

	var spec_path := "tools/art/env_specs/%s.json" % id
	var spec := _read_json(spec_path)
	if spec.is_empty():
		_fail("cannot read spec %s" % spec_path)
		return
	var staging := "art_src/env/%s" % id
	var concept := "art_src/concept/%s_concept.png" % id
	var approval := "tools/art/env_specs/%s.approved" % id

	_ensure_dir(concept.get_base_dir())
	if not _run_tool("concept", PYTHON, ["tools/art/concept.py", spec_path, concept]):
		return
	if not FileAccess.file_exists(approval):
		print("APPROVAL_REQUIRED concept written to %s" % concept)
		print("Review it, then approve by creating %s and re-run." % approval)
		quit(2)
		return

	var blender := _blender_path()
	if blender.is_empty():
		_fail("blender not found; set BLENDER_PATH")
		return
	if not _run_tool("blender", blender, ["--background", "--python", "tools/art/blender/build_env.py", "--", "--spec", spec_path, "--out", staging]):
		return
	if not _run_tool("pack", PYTHON, ["tools/art/pack_env.py", "%s/manifest.json" % staging, "."]):
		return

	var godot := OS.get_executable_path()
	if not _run_tool("import", godot, ["--headless", "--import"]):
		return

	var kit_args: Array = [
		"--headless", "--script", "res://tools/art/build_env_kit.gd", "--",
		"--atlas", "res://assets/art/env/%s.json" % id,
		"--out", "res://data/env/%s_kit.tres" % id,
	]
	if not _run_tool("kit", godot, kit_args):
		return

	var debug: Node = root.get_node_or_null("DebugManager")
	if debug != null and debug.has_method("register_combat_event"):
		debug.register_combat_event("env_pipeline", {"id": id, "staging": staging, "kit": "data/env/%s_kit.tres" % id})
	print("ENV_PIPELINE_OK %s" % id)
	quit(0)

func _blender_path() -> String:
	var from_env := OS.get_environment("BLENDER_PATH")
	if not from_env.is_empty():
		return from_env
	for candidate: String in BLENDER_CANDIDATES:
		if FileAccess.file_exists(candidate):
			return candidate
	for directory: String in OS.get_environment("PATH").split(";", false):
		for executable: String in ["blender.exe", "blender"]:
			var candidate := directory.path_join(executable)
			if FileAccess.file_exists(candidate):
				return candidate
	return ""

func _run_tool(label: String, executable: String, arguments: Array) -> bool:
	var output: Array = []
	var code := OS.execute(executable, PackedStringArray(arguments), output, true)
	for line: String in output:
		var trimmed := line.strip_edges()
		if not trimmed.is_empty():
			print("[%s] %s" % [label, trimmed])
	if code != 0:
		_fail("%s stage failed (exit %d)" % [label, code])
		return false
	return true

func _read_json(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}

func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + path))

func _fail(message: String) -> void:
	printerr("ENV_PIPELINE_FAIL %s" % message)
	quit(1)
