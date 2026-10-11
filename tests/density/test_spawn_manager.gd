extends RefCounted

func get_suite_name() -> String:
	return "mob_density"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = true
	await t.physics_frame
	await t.physics_frame

	var spawner: Node = t.root.get_node_or_null("SpawnManager")
	t.assert_true(spawner != null, "spawn manager autoload exists")
	if spawner == null:
		t.complete_suite(get_suite_name())
		return
	t.assert_true(spawner.get("enabled"), "spawn manager starts enabled")

	var zone: SpawnZone = world.get_node_or_null("ZoneFloor") as SpawnZone
	t.assert_true(zone != null, "test room has a configurable spawn zone")
	if zone == null:
		t.complete_suite(get_suite_name())
		return
	t.assert_true(spawner.get("max_active_mobs") >= 250, "mob cap allows dense packs")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")
	t.assert_true(definition.mob_scene != null, "mob definition carries its scene (data-driven spawning)")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true
	DebugManager.reset_counters()

	var _fill = func(count: int) -> Array:
		var spawned: Array = []
		for index in range(count):
			var mob: Mob = mob_scene.instantiate()
			mob.definition = definition
			mob.global_position = Vector2(-230.0 + float(index) * (460.0 / float(maxf(1.0, float(count - 1)))), -30.0)
			world.add_child(mob)
			spawned.append(mob)
		for _i in range(6):
			await t.physics_frame
		return spawned

	var _wait_for_active = func(target: int, max_frames: int) -> bool:
		for _i in range(max_frames):
			if spawner.get("active_mob_count").call() == target:
				return true
			await t.physics_frame
		return spawner.get("active_mob_count").call() == target

	var _kill_all = func() -> int:
		var killed := 0
		for mob in t.get_nodes_in_group("enemies"):
			if is_instance_valid(mob) and not mob.is_dead():
				mob.take_damage(999999.0, null)
				killed += 1
		return killed

	var _record_metrics = func(label: String) -> void:
		var stats: Dictionary = spawner.get("stats").call()
		DebugManager.register_combat_event("density_probe", {
			"label": label,
			"active": stats.get("active", 0),
			"pooled": stats.get("pooled", 0),
			"created": stats.get("created", 0),
			"reused": stats.get("reused", 0),
			"enemies": t.get_nodes_in_group("enemies").size(),
			"fps": Engine.get_frames_per_second(),
			"frame_ms": DebugManager.frame_time_ms(),
			"memory_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		})
		print("density [%s]: %s" % [label, stats])

	zone.capacity = 100
	spawner.set("max_active_mobs", 250)
	var filled_100: bool = await _wait_for_active.call(100, 300)
	t.assert_true(filled_100, "100 mobs are active (have %d)" % spawner.get("active_mob_count").call())
	t.assert_eq(zone.live_count(), 100, "zone fills to its capacity of 100")
	_record_metrics.call("100_mobs")

	spawner.set("max_active_mobs", 200)
	zone.capacity = 250
	var capped: bool = await _wait_for_active.call(200, 300)
	t.assert_true(capped, "the global mob cap clamps spawning at 200 (have %d)" % spawner.get("active_mob_count").call())
	_record_metrics.call("capped_200")

	spawner.set("max_active_mobs", 250)
	var filled_250: bool = await _wait_for_active.call(250, 400)
	t.assert_true(filled_250, "250 mobs are active (have %d)" % spawner.get("active_mob_count").call())
	_record_metrics.call("250_mobs")

	var killed: int = await _kill_all.call()
	t.assert_true(killed >= 250, "mass kill reaches every active mob (killed %d)" % killed)
	var pooled_up: bool = await _wait_for_pooled(t, 250, 120)
	t.assert_true(pooled_up, "dead mobs are pooled instead of freed")
	_record_metrics.call("after_mass_death")

	var stats_after_death: Dictionary = spawner.get("stats").call()
	t.assert_eq(stats_after_death.get("active"), 0, "no active mobs remain after mass death")
	t.assert_eq(stats_after_death.get("pooled"), 250, "all 250 dead mobs sit in the pool")

	var created_before_reuse: int = stats_after_death.get("created")
	zone.respawn_delay = 0.5
	var respawned_full: bool = await _wait_for_active.call(250, 600)
	t.assert_true(respawned_full, "the zone respawns back to capacity (have %d)" % spawner.get("active_mob_count").call())
	var stats_reused: Dictionary = spawner.get("stats").call()
	t.assert_eq(stats_reused.get("created"), created_before_reuse, "respawn reuses pooled mobs, creating no new instances")
	t.assert_true(stats_reused.get("reused") >= 250, "recycled mobs are reused (reused %d)" % stats_reused.get("reused", 0))
	_record_metrics.call("after_respawn")

	zone.capacity = 20
	await _kill_all.call()
	await _wait_for_inactive(t, 120)
	var respawned: bool = await _wait_for_active.call(20, 400)
	t.assert_true(respawned, "the zone respawns mobs up to capacity (have %d)" % spawner.get("active_mob_count").call())
	t.assert_true(zone.live_count() == 20, "respawned mobs are tracked by the zone")

	await _kill_all.call()
	await _wait_for_inactive(t, 120)
	var final_stats: Dictionary = spawner.get("stats").call()
	t.assert_true(final_stats.get("active") == 0, "zone can be fully cleared again")
	_record_metrics.call("after_respawn_cycle")

	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	spawner.set("enabled", false)
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _wait_for_inactive(t, max_frames: int) -> bool:
	var spawner: Node = t.root.get_node_or_null("SpawnManager")
	for _i in range(max_frames):
		if spawner.get("active_mob_count").call() == 0:
			return true
		await t.physics_frame
	return spawner.get("active_mob_count").call() == 0

func _wait_for_pooled(t, target: int, max_frames: int) -> bool:
	var spawner: Node = t.root.get_node_or_null("SpawnManager")
	for _i in range(max_frames):
		var stats: Dictionary = spawner.get("stats").call()
		if stats.get("pooled", 0) >= target:
			return true
		await t.physics_frame
	var final_stats: Dictionary = spawner.get("stats").call()
	return final_stats.get("pooled", 0) >= target
