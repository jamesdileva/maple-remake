extends RefCounted

func get_suite_name() -> String:
	return "input_bindings"

func run(t) -> void:
	var gameplay_actions := [
		"move_left", "move_right", "move_up", "move_down",
		"jump", "attack", "interact",
		"skill_1", "skill_2", "skill_3", "skill_4",
	]
	for action_name: String in gameplay_actions:
		t.assert_true(InputMap.has_action(action_name), "action exists: %s" % action_name)
		var has_pc := false
		var has_joy := false
		for event: InputEvent in InputMap.action_get_events(action_name):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_joy = true
			else:
				has_pc = true
		t.assert_true(has_pc, "%s has keyboard/mouse binding" % action_name)
		t.assert_true(has_joy, "%s has gamepad binding" % action_name)

	var debug_actions := ["debug_overlay", "debug_export", "debug_god", "debug_kill_all", "debug_reload_scene"]
	for action_name: String in debug_actions:
		t.assert_true(InputMap.has_action(action_name), "debug action exists: %s" % action_name)
		t.assert_true(InputMap.action_get_events(action_name).size() > 0, "%s has bindings" % action_name)

	_assert_action_has_key(t, "jump", KEY_SPACE)
	_assert_action_has_key(t, "jump", JOY_BUTTON_A)
	_assert_action_has_key(t, "attack", MOUSE_BUTTON_LEFT)
	_assert_action_has_key(t, "attack", JOY_BUTTON_X)
	_assert_action_has_key(t, "interact", KEY_E)
	_assert_action_has_key(t, "interact", JOY_BUTTON_B)
	_assert_action_has_key(t, "skill_1", KEY_1)
	_assert_action_has_key(t, "skill_1", JOY_BUTTON_Y)
	_assert_action_has_key(t, "skill_2", KEY_2)
	_assert_action_has_key(t, "skill_2", JOY_BUTTON_LEFT_SHOULDER)
	_assert_action_has_key(t, "skill_3", KEY_3)
	_assert_action_has_key(t, "skill_3", JOY_BUTTON_RIGHT_SHOULDER)
	_assert_action_has_key(t, "skill_4", KEY_4)
	_assert_action_has_key(t, "debug_god", KEY_F1)
	_assert_action_has_key(t, "debug_export", KEY_F8)

	var move_left := InputMap.action_get_events("move_left")
	t.assert_true(move_left.any(_is_key_named.bind(KEY_A)), "move_left binds A")
	t.assert_true(move_left.any(_is_key_named.bind(KEY_LEFT)), "move_left binds Left arrow")
	t.assert_true(move_left.any(_is_stick.bind(JOY_AXIS_LEFT_X, -1.0)), "move_left binds left stick -X")

	var move_right := InputMap.action_get_events("move_right")
	t.assert_true(move_right.any(_is_key_named.bind(KEY_RIGHT)), "move_right binds Right arrow")
	t.assert_true(move_right.any(_is_stick.bind(JOY_AXIS_LEFT_X, 1.0)), "move_right binds left stick +X")

	var space_press := InputEventKey.new()
	space_press.physical_keycode = KEY_SPACE
	space_press.pressed = true
	Input.parse_input_event(space_press)
	await t.process_frame
	t.assert_true(Input.is_action_pressed("jump"), "space key press triggers jump action")
	var space_release := InputEventKey.new()
	space_release.physical_keycode = KEY_SPACE
	space_release.pressed = false
	Input.parse_input_event(space_release)
	await t.process_frame
	t.assert_false(Input.is_action_pressed("jump"), "space release clears jump action")

	var a_press := InputEventJoypadButton.new()
	a_press.button_index = JOY_BUTTON_A
	a_press.pressed = true
	Input.parse_input_event(a_press)
	await t.process_frame
	t.assert_true(Input.is_action_pressed("jump"), "gamepad A press triggers jump action")

func _assert_action_has_key(t, action_name: String, code: int) -> void:
	var events: Array = InputMap.action_get_events(action_name)
	t.assert_true(
		events.any(_matches_code.bind(code)),
		"%s includes input code %d" % [action_name, code],
	)

func _matches_code(event: InputEvent, code: int) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).physical_keycode == code
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).button_index == code
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == code
	return false

func _is_key_named(event: InputEvent, code: int) -> bool:
	return event is InputEventKey and (event as InputEventKey).physical_keycode == code

func _is_stick(event: InputEvent, axis: int, value: float) -> bool:
	if not event is InputEventJoypadMotion:
		return false
	var motion: InputEventJoypadMotion = event
	return motion.axis == axis and is_equal_approx(motion.axis_value, value)
