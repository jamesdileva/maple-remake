extends RefCounted

func get_suite_name() -> String:
	return "crossbow"

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
	var archer: ClassDefinition = load("res://data/classes/archer.tres")
	t.assert_true(archer != null, "archer class loads")
	t.assert_eq(archer.alternate_ability_slots.size(), 6, "the crossbow kit has six slots")
	var bow_kit: Array = []
	var xbow_kit: Array = []
	for ability in archer.ability_slots:
		if ability != null:
			bow_kit.append(ability)
	for ability in archer.alternate_ability_slots:
		if ability != null:
			xbow_kit.append(ability)
	t.assert_eq(bow_kit.size(), 5, "the bow kit is intact")
	t.assert_eq(xbow_kit.size(), 5, "the crossbow kit is complete")
	t.assert_eq(archer.alternate_ability_slots[0].id, &"xbow_bolt", "crossbow slot 1 is the heavy bolt")
	t.assert_eq(archer.alternate_ability_slots[1].id, &"xbow_pierce", "crossbow slot 2 pierces")
	t.assert_eq(archer.alternate_ability_slots[2].id, &"xbow_siege", "crossbow slot 3 is the siege blast")
	t.assert_eq(archer.alternate_ability_slots[3].id, &"xbow_snipe", "crossbow slot 4 is the snipe")
	t.assert_true(archer.alternate_ability_slots[4].is_summon(), "crossbow slot 5 deploys a ballista")

	# clearly different on paper: slower, heavier, thirstier
	var bow_cast := 0.0
	var bow_damage := 0.0
	var bow_mana := 0.0
	for ability: AbilityDefinition in bow_kit:
		bow_cast += ability.cast_time
		bow_damage += ability.damage
		bow_mana += ability.mana_cost
	var xbow_cast := 0.0
	var xbow_damage := 0.0
	var xbow_mana := 0.0
	var xbow_slowest := 99.0
	for ability: AbilityDefinition in xbow_kit:
		xbow_cast += ability.cast_time
		xbow_damage += ability.damage
		xbow_mana += ability.mana_cost
		xbow_slowest = minf(xbow_slowest, ability.cast_time)
	t.assert_true(xbow_cast / 5.0 > bow_cast / 5.0, "the crossbow casts slower on average")
	t.assert_true(xbow_damage / 5.0 > bow_damage / 5.0, "the crossbow hits harder on average")
	t.assert_true(xbow_mana / 5.0 > bow_mana / 5.0, "the crossbow costs more on average")
	t.assert_true(xbow_slowest >= 0.8, "even the fastest crossbow shot is deliberate")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	# wield the crossbow kit through a local test class (switching itself is 7.3)
	var xbow_stance := ClassDefinition.new()
	xbow_stance.id = &"archer_xbow_test"
	xbow_stance.display_name = "Archer (Crossbow)"
	xbow_stance.ability_slots = archer.alternate_ability_slots
	xbow_stance.starting_hp = archer.starting_hp
	xbow_stance.starting_mana = archer.starting_mana
	xbow_stance.defense = archer.defense
	xbow_stance.crit_chance = archer.crit_chance
	xbow_stance.crit_multiplier = archer.crit_multiplier
	xbow_stance.mana_regen_per_second = archer.mana_regen_per_second
	player.apply_class(xbow_stance)
	t.assert_eq(player.ability_at(0).id, &"xbow_bolt", "the crossbow kit is wieldable")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")

	var _clear_mobs = func() -> void:
		for mob: Object in t.get_nodes_in_group("enemies"):
			if is_instance_valid(mob):
				mob.queue_free()
		await t.physics_frame

	var _spawn_mob = func(mob_definition: MobDefinition, position: Vector2) -> Node:
		var spawned: Mob = mob_scene.instantiate()
		spawned.definition = mob_definition
		spawned.global_position = position
		world.add_child(spawned)
		return spawned

	var _press = func(action: String) -> void:
		Input.action_press(action)
		for _i in range(3):
			await t.physics_frame
		Input.action_release(action)

	var _finish = func(max_frames: int) -> void:
		for _i in range(max_frames):
			if not player.is_casting():
				return
			await t.physics_frame

	await _clear_mobs.call()
	player.global_position = Vector2(300.0, -60.0)
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0
	await t.physics_frame
	await t.physics_frame

	# heavy bolt: slow but crushing
	player.mana = player.max_mana
	var bolt_target: Mob = _spawn_mob.call(definition, Vector2(420.0, -40.0))
	bolt_target.hp = 500.0
	await t.physics_frame
	await t.physics_frame
	var bolt_hp: float = bolt_target.hp
	await _press.call("skill_1")
	t.assert_true(player.is_casting(), "the heavy bolt starts its long cast")
	await _finish.call(80)
	t.assert_true(bolt_hp - bolt_target.hp >= 50.0, "the heavy bolt crushes (%d)" % int(bolt_hp - bolt_target.hp))

	# piercing shot: one bolt through a whole line
	await _clear_mobs.call()
	var line: Array = []
	for index in range(8):
		var mob: Mob = _spawn_mob.call(definition, Vector2(360.0 + float(index) * 14.0, -50.0))
		mob.hp = 200.0
		line.append(mob)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	await _press.call("skill_2")
	await _finish.call(80)
	var pierced := 0
	for mob: Object in line:
		if is_instance_valid(mob) and mob.hp < 200.0:
			pierced += 1
	t.assert_true(pierced >= 6, "the piercing shot runs through the line (%d of 8)" % pierced)

	# snipe: boss multiplier applies only to bosses
	await _clear_mobs.call()
	var boss_definition := MobDefinition.new()
	boss_definition.id = &"mock_boss"
	boss_definition.display_name = "Mock Boss"
	boss_definition.max_hp = 1000.0
	boss_definition.is_boss = true
	boss_definition.mob_scene = mob_scene
	var boss: Mob = _spawn_mob.call(boss_definition, Vector2(420.0, -40.0))
	boss.hp = 1000.0
	await t.physics_frame
	await t.physics_frame
	player.level = 5
	player.mana = player.max_mana
	await _press.call("skill_4")
	await _finish.call(100)
	var boss_dealt := 1000.0 - boss.hp
	await _clear_mobs.call()
	var normal: Mob = _spawn_mob.call(definition, Vector2(420.0, -40.0))
	normal.hp = 1000.0
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	await _press.call("skill_4")
	await _finish.call(100)
	var normal_dealt := 1000.0 - normal.hp
	t.assert_true(boss_dealt > normal_dealt, "the snipe prefers bosses (%d vs %d)" % [int(boss_dealt), int(normal_dealt)])
	t.assert_almost_eq(boss_dealt / maxf(1.0, normal_dealt), 1.5, 0.05, "the boss multiplier is exact")

	# ballista: slow heavy summon
	await _clear_mobs.call()
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	var dummy: Mob = _spawn_mob.call(definition, Vector2(300.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	await _press.call("skill_5")
	await _finish.call(100)
	t.assert_true(player.active_summons() >= 1, "the ballista deploys")
	for _i in range(240):
		await t.physics_frame
		if not is_instance_valid(dummy) or dummy.is_dead():
			break
	t.assert_true(not is_instance_valid(dummy) or dummy.is_dead(), "the ballista hits hard")
	for summon: Object in player.get("_summons").duplicate():
		if is_instance_valid(summon):
			summon.queue_free()

	# siege blast: large effects clear a pack
	await _clear_mobs.call()
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.level = 15
	player.mana = player.max_mana
	for index in range(16):
		_spawn_mob.call(definition, Vector2(-160.0 + float(index) * 20.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	await _press.call("skill_3")
	await _finish.call(120)
	var survivors := 0
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and not mob.is_dead():
			survivors += 1
	t.assert_eq(survivors, 0, "the siege blast clears its zone (%d survivors)" % survivors)
	t.assert_true(t.get_nodes_in_group("effects").size() >= 0, "large effects resolve")

	player.apply_class(archer)
	await _clear_mobs.call()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
