extends RefCounted

func get_suite_name() -> String:
	return "fma"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	await t.physics_frame
	var player: Player = world.get_node("Player")
	player.hp = player.max_hp
	player.mana = player.max_mana
	player.mana_regen_per_second = 0.0
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame

	for child: Node in world.get_children():
		if child.is_in_group("enemies"):
			child.queue_free()
	await t.physics_frame
	await t.physics_frame

	DebugManager.reset_counters()
	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	var ability: AbilityDefinition = load("res://data/abilities/arc_storm.tres")
	t.assert_true(ability != null, "fma ability loads from data")
	t.assert_eq(ability.id, &"arc_storm", "fma ability carries its id")
	t.assert_eq(ability.area_mode, AbilityDefinition.AreaMode.CENTERED, "fma targets a centered area")
	t.assert_true(ability.range >= 400.0, "fma covers a large area (range=%s)" % ability.range)
	t.assert_true(ability.mana_cost > 0.0, "fma is limited by a mana cost")
	t.assert_true(ability.cast_time > 0.0, "fma is limited by a cast time")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")

	var _spawn_pack = func(count: int) -> Array:
		var spawned: Array = []
		for index in range(count):
			var spawned_mob: Mob = mob_scene.instantiate()
			spawned_mob.definition = definition
			var spread := count > 1
			var offset := -200.0 + float(index) * (400.0 / float(count - 1)) if spread else 0.0
			spawned_mob.global_position = Vector2(offset, -30.0)
			world.add_child(spawned_mob)
			spawned.append(spawned_mob)
		for _i in range(4):
			await t.physics_frame
		return spawned

	var first_pack: Array = await _spawn_pack.call(1)
	var mana_before: float = player.mana
	var casts_before: float = DebugManager.counters.casts
	var completions: Array = []
	EventBus.ability_cast_completed.connect(func(cast: AbilityDefinition, targets_hit: int):
		completions.append({"ability": cast.id, "targets_hit": targets_hit}))

	await _press_ability(t, "skill_2")
	t.assert_true(player.is_casting(), "fma starts casting")
	t.assert_eq(player.mana, mana_before - ability.mana_cost, "mana is deducted exactly once at cast start")

	await _press_ability(t, "skill_2")
	t.assert_eq(player.mana, mana_before - ability.mana_cost, "casting again mid-cast does not spend mana")
	t.assert_true(player.is_casting(), "cast cannot be repeated instantly")

	var finished := await _wait_until(t, func() -> bool:
		return not player.is_casting(), 120)
	t.assert_true(finished, "fma cast completes")
	t.assert_eq(completions.size(), 1, "the fma cast reports one completion")
	t.assert_eq(completions[0].targets_hit, 1, "the single mob is hit by the fma")
	t.assert_true(_is_finished(first_pack[0]), "the single mob dies to the fma")
	t.assert_eq(DebugManager.counters.casts, casts_before + 2.0, "cast start and completion are counted once each")
	t.assert_eq(player.mana, mana_before - ability.mana_cost, "one fma cast spends the cost once, not per target")

	var mana_after_first: float = player.mana
	await _press_ability(t, "skill_2")
	t.assert_true(player.is_casting(), "fma can be cast again after completing (no cooldown)")
	t.assert_eq(player.mana, mana_after_first - ability.mana_cost, "the repeat cast spends mana again")

	for count in [10, 50, 100]:
		await _wait_until(t, func() -> bool: return not player.is_casting(), 120)
		DebugManager.reset_counters()
		player.mana = player.max_mana
		var pack: Array = await _spawn_pack.call(count)
		var pack_mana_before: float = player.mana
		await _press_ability(t, "skill_2")
		t.assert_eq(player.mana, pack_mana_before - ability.mana_cost,
			"%d mobs: mana is deducted once, not per target" % count)
		var cleared := await _wait_until(t, func() -> bool:
			return _live_count(pack) == 0, 240)
		t.assert_true(cleared, "%d mobs: every mob in the area dies (%d left)" % [count, _live_count(pack)])
		t.assert_eq(DebugManager.counters.kills, count, "%d mobs: kill telemetry matches" % count)

	var outside_mob: Mob = await _spawn_single(t, world, mob_scene, definition, 420.0)
	var inside_mana_before: float = player.mana
	await _press_ability(t, "skill_2")
	var outside_hp_before: float = outside_mob.hp
	await _wait_until(t, func() -> bool: return not player.is_casting(), 120)
	t.assert_false(outside_mob.is_dead(), "a mob outside the blast area is not hit")
	t.assert_eq(outside_mob.hp, outside_hp_before, "a mob outside the blast area takes no damage")
	t.assert_true(player.mana < inside_mana_before, "a cast with no targets in range still resolves")

	await _wait_until(t, func() -> bool: return _effects_count(t) == 0, 120)
	t.assert_eq(_effects_count(t), 0, "fma vfx are cleaned up")

	DebugManager.reset_counters()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	Input.action_release("skill_2")
	t.complete_suite(get_suite_name())

func _spawn_single(t, world: Node2D, mob_scene: PackedScene, definition: MobDefinition, x: float) -> Mob:
	var spawned_mob: Mob = mob_scene.instantiate()
	spawned_mob.definition = definition
	spawned_mob.global_position = Vector2(x, -30.0)
	world.add_child(spawned_mob)
	for _i in range(4):
		await t.physics_frame
	return spawned_mob

func _is_finished(mob) -> bool:
	return not is_instance_valid(mob) or mob.is_dead()

func _live_count(mobs: Array) -> int:
	var alive := 0
	for mob in mobs:
		if is_instance_valid(mob) and not mob.is_dead():
			alive += 1
	return alive

func _effects_count(t) -> int:
	return t.get_nodes_in_group("effects").size()

func _press_ability(t, action: String, frames: int = 3) -> void:
	Input.action_press(action)
	for _i in range(frames):
		await t.physics_frame
	Input.action_release(action)

func _wait_until(t, condition: Callable, max_frames: int) -> bool:
	for _i in range(max_frames):
		if condition.call():
			return true
		await t.physics_frame
	return condition.call()
