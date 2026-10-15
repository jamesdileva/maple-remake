extends RefCounted

const BOSS_PATH := "res://data/mobs/benchmark_construct.tres"
const LEVEL := 25
const MAX_CASTS := 120
const MAX_FRAMES := 6000

const FMA_ACTIONS := {
	&"mage": "skill_4",
	&"warrior": "skill_4",
	&"archer": "skill_3",
	&"assassin": "skill_4",
}
const BOSS_SPECIALISTS := {
	&"archer": {"action": "skill_4", "ability": "res://data/abilities/archer_demolition.tres"},
	&"assassin": {"action": "skill_1", "ability": "res://data/abilities/assassin_execution.tres"},
}

func get_suite_name() -> String:
	return "boss_benchmark"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame

	var player: Player = world.get_node("Player")
	var boss_definition: MobDefinition = load(BOSS_PATH)
	t.assert_true(boss_definition != null, "the benchmark construct loads")
	t.assert_true(boss_definition.is_boss, "the benchmark construct is boss-flagged")
	t.assert_eq(boss_definition.xp, 0.0, "the benchmark rewards no xp")
	t.assert_eq(boss_definition.contact_damage, 0.0, "the benchmark never fights back")
	t.assert_eq(boss_definition.loot_table, null, "the benchmark drops no loot")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	player.set_level(LEVEL)
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0

	var meters := {}
	var kill_frames := {}
	for id in [&"mage", &"warrior", &"archer", &"assassin"]:
		player.apply_class(load("res://data/classes/%s.tres" % String(id)) as ClassDefinition)
		player.global_position = Vector2(0.0, -60.0)
		await t.physics_frame
		await t.physics_frame
		var boss: Mob = _spawn(world, boss_definition, Vector2(0.0, -40.0))
		var meter := DamageMeter.new()
		EventBus.damage_applied.connect(meter.record_damage)
		EventBus.mob_died.connect(meter.record_kill)
		EventBus.ability_cast_completed.connect(meter.record_cast)
		meter.start()
		meter.start_boss()
		var result := await _cast_until_dead(t, player, boss, FMA_ACTIONS[id])
		meter.stop()
		meter.stop_boss()
		EventBus.damage_applied.disconnect(meter.record_damage)
		EventBus.mob_died.disconnect(meter.record_kill)
		EventBus.ability_cast_completed.disconnect(meter.record_cast)
		t.assert_true(not is_instance_valid(boss) or boss.is_dead(),
			"the %s kills the benchmark construct" % String(id))
		t.assert_true(result.casts >= 5, "the construct survives a real rotation (%d casts)" % result.casts)
		t.assert_true(meter.kills >= 1, "the %s kill is metered" % String(id))
		var summary := meter.summary()
		t.assert_true(summary.boss_time_sec > 0.0, "boss time is metered for the %s" % String(id))
		t.assert_true(summary.total_damage >= 1500.0,
			"the %s deals at least the construct hp (%d)" % [String(id), int(summary.total_damage)])
		meters[id] = meter
		kill_frames[id] = result.frames
		print("boss_benchmark: %s killed in %d casts (%d frames)" % [String(id), result.casts, result.frames])

	var fastest := 999999.0
	var slowest := 0.0
	for id in kill_frames:
		fastest = minf(fastest, float(kill_frames[id]))
		slowest = maxf(slowest, float(kill_frames[id]))
	t.assert_true(slowest / fastest <= 1.75,
		"no class is catastrophically slower to kill the benchmark (%.2fx)" % (slowest / fastest))

	var strongest_dps := 0.0
	var weakest_dps := 999999.0
	for id in meters:
		var dps: float = meters[id].dps()
		strongest_dps = maxf(strongest_dps, dps)
		weakest_dps = minf(weakest_dps, dps)
	t.assert_true(strongest_dps / weakest_dps <= 2.0,
		"benchmark dps stays inside one band (%.0f vs %.0f)" % [strongest_dps, weakest_dps])

	# boss specialists actually punish the boss more than a normal mob
	for id in BOSS_SPECIALISTS:
		var spec: Dictionary = BOSS_SPECIALISTS[id]
		var ability: AbilityDefinition = load(spec.ability)
		t.assert_true(ability.boss_multiplier > 1.0, "the %s carries a boss multiplier" % String(id))
		player.apply_class(load("res://data/classes/%s.tres" % String(id)) as ClassDefinition)
		player.advance()
		player.crit_chance = -1.0
		player.global_position = Vector2(300.0, -60.0)
		await t.physics_frame
		await t.physics_frame
		var boss_target: Mob = _spawn(world, boss_definition, Vector2(300.0 + ability.range * 0.5, -30.0))
		var plain: MobDefinition = boss_definition.duplicate()
		plain.id = &"benchmark_mob"
		plain.is_boss = false
		await t.physics_frame
		await t.physics_frame
		var boss_hp: float = boss_target.hp
		player.mana = player.max_mana
		await _cast_once(t, player, spec.action)
		var boss_lost := boss_hp - boss_target.hp
		if is_instance_valid(boss_target):
			boss_target.queue_free()
		await t.physics_frame
		var plain_target: Mob = _spawn(world, plain, Vector2(300.0 + ability.range * 0.5, -30.0))
		await t.physics_frame
		await t.physics_frame
		var plain_hp: float = plain_target.hp
		player.mana = player.max_mana
		await _cast_once(t, player, spec.action)
		var plain_lost := plain_hp - plain_target.hp
		t.assert_true(boss_lost > plain_lost,
			"the %s bonus hurts the boss more (%.1f vs %.1f)" % [String(id), boss_lost, plain_lost])
		t.assert_almost_eq(boss_lost, ability.damage_at(1) * ability.boss_multiplier, 0.5,
			"the %s bonus is exactly the data multiplier" % String(id))
		if is_instance_valid(boss_target):
			boss_target.queue_free()
		if is_instance_valid(plain_target):
			plain_target.queue_free()
		await t.physics_frame

	for meter in meters.values():
		t.assert_true(meter.total_damage >= 1500.0, "every metered run recorded full damage")
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _cast_once(t, player: Player, action: String) -> void:
	Input.action_press(action)
	for _i in range(3):
		await t.physics_frame
	Input.action_release(action)
	for _i in range(120):
		if not player.is_casting():
			break
		await t.physics_frame

func _spawn(world: Node2D, definition: MobDefinition, position: Vector2) -> Mob:
	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var spawned: Mob = mob_scene.instantiate()
	spawned.definition = definition
	spawned.global_position = position
	world.add_child(spawned)
	return spawned

func _cast_until_dead(t, player: Player, target: Mob, action: String) -> Dictionary:
	var casts := 0
	var frames := 0
	while casts < MAX_CASTS and frames < MAX_FRAMES:
		if not is_instance_valid(target) or target.is_dead():
			break
		if not player.is_casting():
			player.mana = player.max_mana
			Input.action_press(action)
			for _i in range(3):
				frames += 1
				await t.physics_frame
			Input.action_release(action)
			if player.is_casting():
				casts += 1
			for _i in range(600):
				frames += 1
				await t.physics_frame
				if not player.is_casting():
					break
			continue
		frames += 1
		await t.physics_frame
	return {"casts": casts, "frames": frames}
