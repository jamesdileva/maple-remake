extends RefCounted

func get_suite_name() -> String:
	return "map_framework"

func run(t) -> void:
	var game_scene: PackedScene = load("res://scenes/game/game.tscn")
	var game: Node2D = game_scene.instantiate()
	t.root.add_child(game)
	t.register_world(game)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame

	var player: Player = game.get_node("Player")
	var world: Node2D = game.get_node("World")
	t.assert_eq(WorldManager.current_map_id, &"test_a", "the game boots into the starting map")
	t.assert_eq(world.get_child_count(), 1, "exactly one map is hosted")
	t.assert_almost_eq(player.global_position.x, -700.0, 0.5, "boot lands on the default spawn")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0

	var traveled: Array = []
	WorldManager.map_changed.connect(func(map_id: StringName): traveled.append(map_id))

	t.assert_true(WorldManager.travel_to(&"test_b", &"default"), "direct travel succeeds")
	await t.physics_frame
	await t.physics_frame
	t.assert_eq(WorldManager.current_map_id, &"test_b", "the current map tracks travel")
	t.assert_eq(traveled.size(), 1, "travel emits exactly once")
	t.assert_eq(traveled[0], &"test_b", "the travel event names the map")
	t.assert_eq(world.get_child_count(), 1, "the old map is replaced, never stacked")
	t.assert_almost_eq(player.global_position.x, -700.0, 0.5, "travel lands on the target spawn")
	t.assert_false(WorldManager.travel_to(&"no_such_map", &"default"), "unknown maps are rejected")
	t.assert_eq(WorldManager.current_map_id, &"test_b", "failed travel keeps the current map")

	for _i in range(12):
		await t.physics_frame
	t.assert_true(player.is_on_floor(), "loaded maps provide platform collision")

	# portal travel: A -> B, then grace blocks the instant bounce, then B -> A
	t.assert_true(WorldManager.travel_to(&"test_a", &"default"), "returning to A for the portal check")
	for _i in range(40):
		await t.physics_frame
	t.assert_eq(WorldManager.current_map_id, &"test_a", "settled in A with grace expired")
	player.global_position = Vector2(700.0, -60.0)
	for _i in range(60):
		await t.physics_frame
		if WorldManager.current_map_id == &"test_b":
			break
	t.assert_eq(WorldManager.current_map_id, &"test_b", "walking into the portal travels to B")
	t.assert_almost_eq(player.global_position.x, -700.0, 0.5, "portal travel lands on the B spawn")

	player.global_position = Vector2(700.0, -60.0)
	for _i in range(10):
		await t.physics_frame
	t.assert_eq(WorldManager.current_map_id, &"test_b", "travel grace blocks the instant bounce")
	for _i in range(50):
		await t.physics_frame
		if WorldManager.current_map_id == &"test_a":
			break
	t.assert_eq(WorldManager.current_map_id, &"test_a", "the return portal fires once grace expires")

	# transients reset on travel: summons released, spawner and loot drained
	t.assert_true(WorldManager.travel_to(&"test_b", &"default"), "back to B for the reset check")
	for _i in range(10):
		await t.physics_frame
	player.apply_class(load("res://data/classes/assassin.tres") as ClassDefinition)
	player.mana = player.max_mana
	Input.action_press("skill_5")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("skill_5")
	for _i in range(80):
		if not player.is_casting():
			break
		await t.physics_frame
	t.assert_true(player.active_summons() >= 1, "a shade fights for the assassin")
	SpawnManager.enabled = true
	for _i in range(40):
		await t.physics_frame
	t.assert_true(t.get_nodes_in_group("enemies").size() >= 1, "the B spawn zone ticks live mobs")
	t.assert_true(WorldManager.travel_to(&"test_a", &"default"), "traveling drains transients")
	for _i in range(10):
		await t.physics_frame
	t.assert_eq(player.active_summons(), 0, "summons do not follow across maps")
	t.assert_eq(t.get_nodes_in_group("enemies").size(), 0, "mobs do not follow across maps")
	t.assert_eq(SpawnManager.stats()["spawned"], 0, "the spawner budget resets per map")
	t.assert_eq(LootManager.stats()["spawned"], 0, "pending loot resets per map")

	t.assert_true(WorldManager.travel_to(&"test_b", &"default"), "back to B for the snapshot")
	for _i in range(10):
		await t.physics_frame
	var path: String = DebugManager.export_debug_data()
	var snapshot := FileAccess.get_file_as_string(path)
	t.assert_true(snapshot.contains("current_map"), "the snapshot exposes the current map")
	t.assert_true(snapshot.contains("test_b"), "the snapshot names the traveled map")

	SpawnManager.enabled = false
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	game.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
