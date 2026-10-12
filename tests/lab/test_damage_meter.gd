extends RefCounted

func get_suite_name() -> String:
	return "damage_meter"

func run(t) -> void:
	var scene: PackedScene = load("res://scenes/lab/combat_lab.tscn")
	var lab_root: Node2D = scene.instantiate()
	t.root.add_child(lab_root)
	t.register_world(lab_root)
	await t.physics_frame
	await t.physics_frame

	var lab: CombatLab = lab_root.get_node("Lab")
	var player: Player = lab_root.get_node("Player")
	DebugManager.god_mode = true
	DebugManager.disable_ai = true
	player.crit_chance = 0.0

	lab.meter.reset()
	t.assert_eq(lab.meter.total_damage, 0.0, "the meter starts empty")
	t.assert_eq(lab.meter.hits, 0, "no hits recorded yet")
	t.assert_eq(lab.meter.kills, 0, "no kills recorded yet")

	lab.meter.start()
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")
	var first := _spawn_mob(lab_root, definition, Vector2(120.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	first.take_damage(12.0, player)
	var second := _spawn_mob(lab_root, definition, Vector2(200.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	second.take_damage(12.0, player)
	await t.physics_frame
	lab.meter.stop()
	t.assert_eq(lab.meter.total_damage, 24.0, "the meter totals exact damage")
	t.assert_eq(lab.meter.hits, 2, "the meter counts hits")
	t.assert_eq(lab.meter.crits, 0, "no crits with zero crit chance")
	t.assert_eq(lab.meter.distinct_targets, 2, "two distinct targets recorded")

	player.crit_chance = 1.0
	lab.meter.start()
	var third := _spawn_mob(lab_root, definition, Vector2(280.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	third.take_damage(12.0, player)
	await t.physics_frame
	lab.meter.stop()
	t.assert_eq(lab.meter.crits, 1, "a forced crit is counted")
	t.assert_eq(lab.meter.total_damage, 24.0, "a crit doubles the recorded damage")
	player.crit_chance = 0.0

	lab.meter.start()
	var victim := _spawn_mob(lab_root, definition, Vector2(360.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	victim.take_damage(30.0, player)
	await t.physics_frame
	await t.physics_frame
	lab.meter.stop()
	t.assert_eq(lab.meter.kills, 1, "a lethal hit is counted as a kill")

	lab.meter.start()
	player.mana = player.max_mana
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	var dummy := _spawn_mob(lab_root, definition, Vector2(370.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	Input.action_press("skill_1")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("skill_1")
	for _i in range(60):
		await t.physics_frame
		if not player.is_casting():
			break
	lab.meter.stop()
	t.assert_eq(lab.meter.skill_uses.get(&"mage_fire", 0), 1, "one skill cast recorded")
	t.assert_true(lab.meter.targets_hit_total >= 1, "skill targets recorded")
	Input.action_release("skill_1")

	var first_run := await _scripted_encounter(t, lab_root, lab, player, definition)
	var second_run := await _scripted_encounter(t, lab_root, lab, player, definition)
	t.assert_eq(first_run.total_damage, second_run.total_damage, "identical encounters meter identically")
	t.assert_eq(first_run.hits, second_run.hits, "hit counts are deterministic")
	t.assert_eq(first_run.kills, second_run.kills, "kill counts are deterministic")

	lab.meter.start_boss()
	for _i in range(20):
		await t.physics_frame
	lab.meter.stop_boss()
	t.assert_true(lab.meter.boss_time_sec() > 0.0, "boss timing runs while no boss exists yet")
	t.assert_true(lab.meter.boss_time_sec() < 5.0, "boss timing stays plausible")

	lab.reset_encounter()
	t.assert_eq(lab.meter.total_damage, 0.0, "reset clears the meter")

	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	lab_root.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _scripted_encounter(t, lab_root: Node2D, lab: CombatLab, player: Player, definition: MobDefinition) -> Dictionary:
	lab.reset_encounter()
	lab.meter.start()
	for index in range(5):
		var mob := _spawn_mob(lab_root, definition, Vector2(100.0 + float(index) * 40.0, -30.0))
		await t.physics_frame
		await t.physics_frame
		mob.take_damage(30.0, player)
	await t.physics_frame
	await t.physics_frame
	lab.meter.stop()
	return lab.meter.summary()

func _spawn_mob(lab_root: Node2D, definition: MobDefinition, position: Vector2) -> Mob:
	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var mob: Mob = mob_scene.instantiate()
	mob.definition = definition
	mob.global_position = position
	lab_root.add_child(mob)
	return mob
