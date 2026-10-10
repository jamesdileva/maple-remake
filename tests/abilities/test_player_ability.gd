extends RefCounted

func get_suite_name() -> String:
	return "player_ability"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	await t.physics_frame
	var player: Player = world.get_node("Player")
	player.hp = player.max_hp
	player.mana = player.max_mana
	player.mana_regen_per_second = 0.0
	player.crit_chance = 0.0
	DebugManager.disable_ai = true

	for child: Node in world.get_children():
		if child.is_in_group("enemies"):
			child.queue_free()
	await t.physics_frame
	await t.physics_frame
	DebugManager.reset_counters()

	var ability: AbilityDefinition = load("res://data/abilities/arcane_burst.tres")
	t.assert_true(ability != null, "ability definition loads from data")
	t.assert_eq(ability.id, &"arcane_burst", "ability carries its id")
	t.assert_eq(ability.mana_cost, 20.0, "ability carries a mana cost")
	t.assert_eq(ability.cast_time, 0.5, "ability carries a cast time")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")

	var cast_events: Array = []
	EventBus.ability_cast_started.connect(func(cast: AbilityDefinition): cast_events.append({"phase": &"start", "ability": cast.id}))
	EventBus.ability_cast_completed.connect(func(cast: AbilityDefinition, targets_hit: int):
		cast_events.append({"phase": &"complete", "ability": cast.id, "targets_hit": targets_hit}))

	var _spawn_mob = func(x: float, y: float) -> Node:
		var spawned: Mob = mob_scene.instantiate()
		spawned.definition = definition
		spawned.global_position = Vector2(x, y)
		world.add_child(spawned)
		return spawned

	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame

	var front_mob: Mob = _spawn_mob.call(340.0, -46.0)
	var behind_mob: Mob = _spawn_mob.call(260.0, -46.0)
	await t.physics_frame
	await t.physics_frame

	var front_hp_before: float = front_mob.hp
	var behind_hp_before: float = behind_mob.hp
	var mana_before: float = player.mana
	var casts_before: float = DebugManager.counters.casts

	await _press_ability(t, "skill_1")

	t.assert_true(player.is_casting(), "skill press starts a cast")
	t.assert_eq(player.current_ability(), ability, "cast reports the slotted ability")
	t.assert_eq(player.mana, mana_before - ability.mana_cost, "mana is spent at cast start")
	t.assert_eq(front_mob.hp, front_hp_before, "no damage lands while the cast is running")
	t.assert_eq(behind_mob.hp, behind_hp_before, "no damage lands while the cast is running")

	var telegraph_seen := false
	for _i in range(12):
		await t.physics_frame
		if _effects_count(t) > 0:
			telegraph_seen = true
	t.assert_true(telegraph_seen, "cast telegraph is visible during the cast")
	t.assert_true(player.is_casting(), "cast is still running mid-way")
	t.assert_eq(front_mob.hp, front_hp_before, "damage waits for cast completion")

	var landed := await _wait_until(t, func() -> bool:
		return not player.is_casting(), 60)
	t.assert_true(landed, "cast finishes")
	t.assert_true(front_mob.hp < front_hp_before, "target in front is hit by the ability")
	t.assert_eq(behind_mob.hp, behind_hp_before, "target behind is not hit")
	t.assert_eq(cast_events.size(), 2, "cast start and completion are both reported")
	var completed: Dictionary = cast_events.back()
	t.assert_eq(completed.phase, &"complete", "completion fires after the cast")
	t.assert_eq(completed.targets_hit, 1, "only the front target is hit")

	var mana_after_first_cast := player.mana
	var front_mob_hp_after_cast: float = front_mob.hp
	t.assert_true(front_mob_hp_after_cast < front_hp_before, "ability damage flows through the pipeline")
	t.assert_eq(DebugManager.counters.casts, casts_before + 2.0, "casts are counted in telemetry")

	await _press_ability(t, "skill_1")
	t.assert_true(player.is_casting(), "a second cast can start")
	t.assert_eq(player.mana, mana_after_first_cast - ability.mana_cost, "second cast spends mana")
	var mid_cast_hp: float = front_mob.hp if is_instance_valid(front_mob) else 0.0
	await _press_ability(t, "skill_1")
	t.assert_eq(player.mana, mana_after_first_cast - ability.mana_cost, "casting again mid-cast does not spend mana")
	await _wait_until(t, func() -> bool: return not player.is_casting(), 60)
	t.assert_true(not is_instance_valid(front_mob) or front_mob.hp <= mid_cast_hp, "the queued cast resolves once")

	player.mana = 5.0
	await t.physics_frame
	var poor_mana := player.mana
	await _press_ability(t, "skill_1")
	t.assert_false(player.is_casting(), "not enough mana blocks the cast")
	t.assert_eq(player.mana, poor_mana, "blocked cast spends no mana")

	DebugManager.infinite_mana = true
	await _press_ability(t, "skill_1")
	t.assert_true(player.is_casting(), "infinite mana allows casting with no mana")
	t.assert_eq(player.mana, 5.0, "infinite mana spend is skipped")
	await _wait_until(t, func() -> bool: return not player.is_casting(), 60)
	DebugManager.infinite_mana = false

	player.mana = player.max_mana
	var multi_a: Mob = _spawn_mob.call(340.0, -46.0)
	var multi_b: Mob = _spawn_mob.call(360.0, -70.0)
	await t.physics_frame
	var multi_a_hp: float = multi_a.hp
	var multi_b_hp: float = multi_b.hp
	await _press_ability(t, "skill_1")
	await _wait_until(t, func() -> bool: return not player.is_casting(), 60)
	t.assert_true(multi_a.hp < multi_a_hp, "the ability hits multiple targets")
	t.assert_true(multi_b.hp < multi_b_hp, "the ability hits targets in the lateral width")

	world.queue_free()
	await t.physics_frame
	DebugManager.disable_ai = false
	Input.action_release("skill_1")
	t.complete_suite(get_suite_name())

func _press_ability(t, action: String, frames: int = 3) -> void:
	Input.action_press(action)
	for _i in range(frames):
		await t.physics_frame
	Input.action_release(action)

func _effects_count(t) -> int:
	return t.get_nodes_in_group("effects").size()

func _wait_until(t, condition: Callable, max_frames: int) -> bool:
	for _i in range(max_frames):
		if condition.call():
			return true
		await t.physics_frame
	return condition.call()
