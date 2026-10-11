extends RefCounted

func get_suite_name() -> String:
	return "chain_mobs"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	for child: Node in world.get_children():
		if child.is_in_group("enemies"):
			child.queue_free()
	await t.physics_frame
	await t.physics_frame

	DebugManager.god_mode = true
	DebugManager.disable_ai = true
	DebugManager.reset_counters()

	var parent_definition: MobDefinition = load("res://data/mobs/bomb_slime.tres")
	var child_definition: MobDefinition = load("res://data/mobs/lesser_slime.tres")
	t.assert_true(parent_definition != null, "chain parent definition loads from data")
	t.assert_true(child_definition != null, "chain child definition loads from data")
	t.assert_true(parent_definition.chain != null, "parent carries a death payload")
	t.assert_eq(parent_definition.chain.child_count, 5, "parent spawns 5 children")
	t.assert_eq(parent_definition.chain.child_definition, child_definition, "payload points at the child definition")
	t.assert_eq(parent_definition.max_chain_depth, 1, "parent allows one chain level")
	t.assert_eq(child_definition.max_chain_depth, 0, "children chain no further")

	var xp_events: Array = []
	EventBus.mob_died.connect(func(mob_id: StringName, xp: float, mob_definition: Resource):
		xp_events.append({"mob_id": mob_id, "xp": xp}))

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")

	var _kill_everything = func() -> void:
		var remaining: Array = t.get_nodes_in_group("enemies")
		for entry in remaining:
			if is_instance_valid(entry) and not entry.is_dead():
				entry.take_damage(999999.0, null)
		await t.physics_frame
		await t.physics_frame
		for _i in range(30):
			if t.get_nodes_in_group("enemies").size() == 0:
				break
			await t.physics_frame

	var _spawn = func(mob_definition: MobDefinition, position: Vector2) -> Node:
		var spawned: Mob = mob_scene.instantiate()
		spawned.definition = mob_definition
		spawned.chain_depth = 0
		spawned.global_position = position
		world.add_child(spawned)
		return spawned

	var parent: Mob = _spawn.call(parent_definition, Vector2(0.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	t.assert_true(DebugManager.counters.kills == 0, "parent starts alive")

	parent.take_damage(999999.0, null)
	await t.physics_frame
	await t.physics_frame

	var children: Array = t.get_nodes_in_group("enemies")
	t.assert_eq(children.size(), 5, "parent death spawns 5 children (%d)" % children.size())
	var parent_position: Vector2 = parent.global_position if is_instance_valid(parent) else Vector2.ZERO
	for child in children:
		t.assert_eq(child.chain_depth, 1, "children inherit chain depth 1")
		t.assert_eq(child.mob_id(), child_definition.id, "children are the payload definition")
		t.assert_true(absf(child.global_position.x - parent_position.x) <= 30.0,
			"children spread around the parent")

	var child_xp_before: float = 0.0
	for child in children:
		child_xp_before += child.xp_reward()
	t.assert_eq(child_xp_before, 5.0, "children carry their own xp")

	var explosion_seen := false
	for _i in range(6):
		await t.physics_frame
		if t.get_nodes_in_group("effects").size() > 0:
			explosion_seen = true
	t.assert_true(explosion_seen, "chain death shows an explosion effect")

	for child in children:
		if is_instance_valid(child):
			child.take_damage(999999.0, null)
	await t.physics_frame
	await t.physics_frame

	t.assert_eq(t.get_nodes_in_group("enemies").size(), 0, "children spawn no further mobs (depth cap stops the chain)")
	t.assert_eq(DebugManager.counters.kills, 6, "kill telemetry covers parent and children")
	var total_xp := 0.0
	for entry in xp_events:
		total_xp += entry.xp
	t.assert_eq(total_xp, 10.0, "xp is awarded for every mob in the chain (%s)" % total_xp)

	DebugManager.reset_counters()
	await _kill_everything.call()
	var parent2: Mob = _spawn.call(parent_definition, Vector2(0.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	var stats_before: Dictionary = SpawnManager.stats()
	parent2.take_damage(999999.0, null)
	await t.physics_frame
	await t.physics_frame
	var stats_after: Dictionary = SpawnManager.stats()
	t.assert_eq(stats_after.chain_spawned, stats_before.chain_spawned + 5,
		"chain spawns are counted for the safety budget")
	await _kill_everything.call()

	var _wait_for_children = func(max_frames: int) -> int:
		var last := -1
		for _i in range(max_frames):
			var current: int = t.get_nodes_in_group("enemies").size()
			if current == last:
				return current
			last = current
			await t.physics_frame
		return last

	var _fill_live_budget = func(count: int) -> void:
		var spawner: Node = t.root.get_node_or_null("SpawnManager")
		for index in range(count):
			var filler: Mob = spawner.call("acquire_chain_child", child_definition, Vector2(-200.0 - float(index) * 20.0, -30.0), world)
			if filler != null:
				filler.set_pool_tracked(true)
		await t.physics_frame
		await t.physics_frame

	SpawnManager.max_total_mobs = 10
	await _fill_live_budget.call(8)
	var total_before_cap: int = SpawnManager.stats().get("total", 0)
	t.assert_true(total_before_cap == 8, "fillers occupy the safety budget (%d)" % total_before_cap)
	var chain_before_cap: int = SpawnManager.stats().get("chain_spawned", 0)
	var parent3: Mob = _spawn.call(parent_definition, Vector2(0.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	DebugManager.reset_counters()
	parent3.take_damage(999999.0, null)
	for _i in range(40):
		await t.physics_frame
	var chain_under_cap: int = SpawnManager.stats().get("chain_spawned", 0) - chain_before_cap
	var total_under_cap: int = SpawnManager.stats().get("total", 0)
	t.assert_true(total_under_cap <= 10,
		"total mobs never exceed the safety cap (%d of 10)" % total_under_cap)
	t.assert_true(chain_under_cap < 5,
		"the safety cap stops the full 5-child chain (%d spawned)" % chain_under_cap)
	SpawnManager.max_total_mobs = 600

	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
