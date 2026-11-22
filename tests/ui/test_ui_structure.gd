extends RefCounted

const UI_SCENES := [
	"res://scenes/ui/level_hud.tscn",
	"res://scenes/ui/class_hud.tscn",
	"res://scenes/ui/class_select.tscn",
	"res://scenes/tutorial/coach_overlay.tscn",
	"res://scenes/debug/debug_overlay.tscn",
]
const HUD_SCENES := [
	"res://scenes/ui/level_hud.tscn",
	"res://scenes/ui/class_hud.tscn",
	"res://scenes/tutorial/coach_overlay.tscn",
]
const MIN_FONT := 14.0
const MAX_CONTROLS := 16

func get_suite_name() -> String:
	return "ui_structure"

func run(t) -> void:
	for path: String in UI_SCENES:
		var root := (load(path) as PackedScene).instantiate()
		t.assert_true(root is CanvasLayer, "%s layers over the game" % path.get_file())
		var controls := root.find_children("*", "Control", true, false)
		var dev_tool := path.ends_with("debug_overlay.tscn")
		if not dev_tool:
			t.assert_true(controls.size() <= MAX_CONTROLS,
				"%s stays minimal (%d controls)" % [path.get_file(), controls.size()])
		var labels := 0
		for control in controls:
			if control is Label:
				labels += 1
				if not dev_tool:
					t.assert_true(float((control as Label).get_theme_font_size("font_size")) >= MIN_FONT,
						"%s/%s reads at %d px" % [path.get_file(), control.name,
						(control as Label).get_theme_font_size("font_size")])
		t.assert_true(labels >= 1, "%s communicates through text" % path.get_file())
		if path in HUD_SCENES:
			for control in controls:
				t.assert_eq((control as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
					"%s/%s never blocks the game" % [path.get_file(), control.name])
		if path.ends_with("class_select.tscn"):
			var backdrop := root.get_node_or_null("Backdrop")
			t.assert_true(backdrop != null and (backdrop as ColorRect).mouse_filter == Control.MOUSE_FILTER_STOP,
				"the class picker blocks the game while choosing")
		root.free()

	var game_text: String = _read("res://scenes/game/game.tscn")
	t.assert_true(game_text.contains('instance=ExtResource'), "the game scene wires its layers")
	t.assert_false(game_text.contains("debug_overlay"), "the shipped UI ships without the debug overlay")
	t.assert_true(game_text.contains("Coach"), "the tutorial coach ships with the game")

	t.complete_suite(get_suite_name())

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text
