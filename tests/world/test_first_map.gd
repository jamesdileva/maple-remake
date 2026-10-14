extends RefCounted

func get_suite_name() -> String:
	return "first_map"

func run(t) -> void:
	var definition: MapDefinition = load("res://data/maps/brightwood_outskirts.tres")
	t.assert_true(definition != null, "the outskirts definition loads from data")
	t.assert_eq(definition.id, &"brightwood_outskirts", "the outskirts declares its id")
	t.assert_true(definition.scene != null, "the outskirts has a scene")

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
	t.assert_eq(WorldManager.current_map_id, &"brightwood_outskirts", "the game boots into the outskirts")
	t.assert_almost_eq(player.global_position.x, -1050.0, 0.5, "boot lands on the meadow entry")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0

	for _i in range(12):
		await t.physics_frame
	t.assert_true(player.is_on_floor(), "the meadow floor collides")

	var map_root: Node = world.get_child(0)
	var zones := map_root.find_children("*", "SpawnZone", true, false)
	t.assert_true(zones.size() >= 3, "the meadow fields several hunting grounds (%d)" % zones.size())
	var chained := false
	for zone: SpawnZone in zones:
		if zone.definition != null and zone.definition.chain != null:
			chained = true
	t.assert_true(chained, "one ground hides chain slimes")

	var npcs := map_root.find_children("*", "NPC", true, false)
	t.assert_eq(npcs.size(), 1, "a villager greets newcomers")
	var maren := npcs[0] as NPC
	t.assert_true(maren != null and not String(maren.dialogue_line).is_empty(), "the villager has guidance to share")
	t.assert_false(maren.is_talking_to(player), "the villager stays quiet at a distance")
	player.global_position = Vector2(-880.0, -40.0)
	await t.physics_frame
	await t.physics_frame
	t.assert_true(maren.is_talking_to(player), "the villager greets the player up close")
	var talked: Array = []
	maren.talked.connect(func(_npc_id: StringName): talked.append(1))
	Input.action_press("interact")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("interact")
	t.assert_eq(talked.size(), 1, "talking to the villager registers exactly once")

	var music := map_root.find_children("*", "MapMusic", true, false)
	t.assert_eq(music.size(), 1, "the meadow carries its own music")
	var tune := music[0] as MapMusic
	t.assert_true(tune.stream != null, "the music has an audible stream")
	tune.play()
	await t.physics_frame
	t.assert_true(tune.playing, "the meadow theme plays")

	SpawnManager.enabled = true
	LootManager.enabled = true
	for _i in range(60):
		await t.physics_frame
	t.assert_true(t.get_nodes_in_group("enemies").size() >= 5, "the hunting grounds fill with slimes")

	player.global_position = Vector2(-400.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	var currency_before: int = player.get_inventory().currency
	var gel_before: int = player.get_inventory().items.get(&"slime_gel", 0)
	player.mana = player.max_mana
	Input.action_press("skill_4")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("skill_4")
	for _i in range(120):
		if not player.is_casting():
			break
		await t.physics_frame
	for _i in range(180):
		await t.physics_frame
	var currency_after: int = player.get_inventory().currency
	var gel_after: int = player.get_inventory().items.get(&"slime_gel", 0)
	t.assert_true(currency_after > currency_before or gel_after > gel_before,
		"cleared slimes pay out loot without picking anything up")

	var exits: Array = []
	for portal: Portal in map_root.find_children("*", "Portal", true, false):
		exits.append(portal)
	t.assert_eq(exits.size(), 1, "one east gate leaves the meadow")
	t.assert_eq((exits[0] as Portal).target_map_id, &"test_b", "the gate points at the next region")
	player.global_position = Vector2(1100.0, -60.0)
	for _i in range(120):
		await t.physics_frame
		if WorldManager.current_map_id == &"test_b":
			break
	t.assert_eq(WorldManager.current_map_id, &"test_b", "walking out finishes the map")

	var path: String = DebugManager.export_debug_data()
	t.assert_true(FileAccess.get_file_as_string(path).contains("test_b"), "the snapshot follows the player out")

	SpawnManager.enabled = false
	LootManager.enabled = false
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	game.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
