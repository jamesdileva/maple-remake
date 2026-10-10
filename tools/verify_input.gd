extends SceneTree

const GAMEPLAY_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "interact", "skill_1", "skill_2", "skill_3", "skill_4"]

var _frame := 0

func _initialize() -> void:
	var ok := true
	for action_name: String in GAMEPLAY_ACTIONS:
		if not InputMap.has_action(action_name):
			print("MISSING ACTION: ", action_name)
			ok = false
			continue
		var has_pc := false
		var has_joy := false
		for event: InputEvent in InputMap.action_get_events(action_name):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_joy = true
			else:
				has_pc = true
		print(action_name, " pc_binding=", has_pc, " joypad_binding=", has_joy)
		if not has_pc or not has_joy:
			ok = false

	for action_name: String in ["debug_overlay", "debug_export"]:
		print(action_name, " events=", InputMap.action_get_events(action_name).size())
		if not InputMap.has_action(action_name):
			ok = false

	print("game/debug/enabled: ", ProjectSettings.get_setting("game/debug/enabled"))
	print("game/debug/overlay_visible: ", ProjectSettings.get_setting("game/debug/overlay_visible"))
	print("game/debug/log_to_file: ", ProjectSettings.get_setting("game/debug/log_to_file"))
	print("BINDING AUDIT: ", "PASS" if ok else "FAIL")

	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	if not ok:
		quit(1)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		print("jump pressed (keyboard, frame 2): ", Input.is_action_pressed("jump"))
		var space_up := InputEventKey.new()
		space_up.physical_keycode = KEY_SPACE
		Input.parse_input_event(space_up)
	if _frame == 3:
		print("jump pressed (released, frame 3): ", Input.is_action_pressed("jump"))
		var a_button := InputEventJoypadButton.new()
		a_button.button_index = JOY_BUTTON_A
		a_button.pressed = true
		Input.parse_input_event(a_button)
	if _frame == 4:
		print("jump pressed (gamepad A, frame 4): ", Input.is_action_pressed("jump"))
		var stick := InputEventJoypadMotion.new()
		stick.axis = JOY_AXIS_LEFT_X
		stick.axis_value = -1.0
		Input.parse_input_event(stick)
	if _frame == 5:
		print("move_left strength (stick -1, frame 5): ", Input.get_action_strength("move_left"))
		quit(0)
	return false
