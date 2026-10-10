extends RefCounted

func get_suite_name() -> String:
	return "player_movement"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	var player: Player = world.get_node("Player")
	var observed_states: Array = []
	player.state_changed.connect(func(new_state: StringName): observed_states.append(new_state))

	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	t.assert_true(player.is_on_floor(), "player lands on floor at spawn")
	t.assert_eq(player.state, Player.State.IDLE, "player starts idle")

	var start_x := player.global_position.x
	Input.action_press("move_right", 1.0)
	for _i in range(30):
		await t.physics_frame
	t.assert_true(player.global_position.x > start_x + 80.0, "player moves right (%s)" % player.global_position.x)
	t.assert_true(absf(player.velocity.x - player.run_speed) < 6.0, "player reaches run speed")
	t.assert_eq(player.state, Player.State.RUN, "player is running")
	t.assert_true(observed_states.has(&"run"), "state_changed emitted 'run'")

	Input.action_release("move_right")
	var drifted_x := player.global_position.x
	for _i in range(30):
		await t.physics_frame
	t.assert_true(absf(player.velocity.x) < 1.0, "player decelerates to a stop")
	t.assert_true(player.global_position.x - drifted_x < 30.0, "deceleration stops quickly")
	t.assert_eq(player.state, Player.State.IDLE, "player returns to idle")

	Input.action_press("jump")
	for _i in range(6):
		await t.physics_frame
	Input.action_release("jump")
	var lifted := false
	for _i in range(40):
		await t.physics_frame
		if player.global_position.y < -100.0:
			lifted = true
			break
	t.assert_true(lifted, "jump lifts the player")
	t.assert_true(observed_states.has(&"jump"), "state_changed emitted 'jump'")

	var falling := false
	for _i in range(80):
		await t.physics_frame
		if not player.is_on_floor() and player.velocity.y > 0.0:
			falling = true
			break
	t.assert_true(falling, "player is airborne and falling")
	var velocity_before: float = player.velocity.y
	Input.action_press("jump")
	await t.physics_frame
	await t.physics_frame
	Input.action_release("jump")
	t.assert_true(player.velocity.y > velocity_before - 60.0, "no infinite jumping mid-air")

	var landed := false
	for _i in range(180):
		await t.physics_frame
		if player.is_on_floor():
			landed = true
			break
	t.assert_true(landed, "gravity returns the player to the floor")

	var manager: Node = t.root.get_node_or_null("DebugManager")
	t.assert_true(manager != null, "DebugManager present during gameplay")
	var start_pos := player.global_position
	manager.teleport_player(Vector2(-200.0, -600.0))
	t.assert_true(player.global_position.is_equal_approx(start_pos) == false, "teleport moves the player")
	manager.teleport_player(Vector2(0.0, -60.0))

	for _i in range(240):
		await t.physics_frame
		if player.is_on_floor():
			break
	t.assert_true(player.is_on_floor(), "player lands again after teleport")

	world.queue_free()
	await t.physics_frame
	Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_release("move_left")
