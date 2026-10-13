extends RefCounted

func get_suite_name() -> String:
	return "archer_class"

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
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	var warrior: ClassDefinition = load("res://data/classes/warrior.tres")
	t.assert_true(archer != null, "archer class definition loads from data")
	t.assert_eq(archer.id, &"archer", "the archer declares its id")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	# balanced identity: between mage fragility and warrior bulk
	t.assert_true(archer.starting_hp > mage.starting_hp, "the archer is sturdier than the mage")
	t.assert_true(archer.starting_hp < warrior.starting_hp, "the archer is lighter than the warrior")
	t.assert_true(archer.defense > mage.defense, "the archer mitigates more than the mage")
	t.assert_true(archer.defense < warrior.defense, "the archer mitigates less than the warrior")
	t.assert_true(archer.crit_chance > mage.crit_chance, "precision: the archer crits more often")

	player.apply_class(archer)
	t.assert_eq(player.max_hp, archer.starting_hp + archer.party_hp_bonus, "the archer kit HP applies")
	t.assert_eq(player.get_defense(), archer.defense, "the archer mitigation is active")

	# fast identity: every bow cast is quick
	var slots := archer.ability_slots
	var non_null := 0
	var slowest := 0.0
	for ability: AbilityDefinition in slots:
		if ability == null:
			continue
		non_null += 1
		slowest = maxf(slowest, ability.cast_time)
	t.assert_eq(non_null, 5, "the bow fills five slots")
	t.assert_true(slowest <= 0.8, "the whole bow kit casts fast (slowest %.2fs)" % slowest)
	t.assert_eq(player.ability_at(0).id, &"archer_quick_shot", "slot 1 is the quick shot")
	t.assert_eq(player.ability_at(1).id, &"archer_scatter", "slot 2 is the scatter volley")
	t.assert_eq(player.ability_at(2).id, &"archer_rain", "slot 3 is the arrow rain")
	t.assert_eq(player.ability_at(3).id, &"archer_bomb", "slot 4 is the arrow bomb")
	t.assert_true(player.ability_at(2).area_mode == AbilityDefinition.AreaMode.CENTERED,
		"the arrow rain is a centered blast")
	t.assert_true(player.ability_at(4).is_summon(), "slot 5 is a summon")
	t.assert_eq(player.ability_at(5), null, "slot 6 is empty for the crossbow")
	t.assert_true(player.ability_at(0).range > 200.0, "the bow outranges melee")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")

	var _clear_mobs = func() -> void:
		for mob: Object in t.get_nodes_in_group("enemies"):
			if is_instance_valid(mob):
				mob.queue_free()
		await t.physics_frame

	var _spawn_mob = func(position: Vector2) -> Node:
		var spawned: Mob = mob_scene.instantiate()
		spawned.definition = definition
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

	# quick shot: cheap single-target at long range
	player.mana = player.max_mana
	var target: Mob = _spawn_mob.call(Vector2(420.0, -40.0))
	target.hp = 200.0
	await t.physics_frame
	await t.physics_frame
	var hp_before: float = target.hp
	var mana_before: float = player.mana
	await _press.call("skill_1")
	await _finish.call(60)
	t.assert_true(target.hp < hp_before, "the quick shot damages at long range")
	t.assert_true(mana_before - player.mana <= 8.0, "the quick shot is cheap")

	# scatter volley: wide multi-target
	await _clear_mobs.call()
	var volleyed: Array = []
	for index in range(5):
		var mob: Mob = _spawn_mob.call(Vector2(380.0 + float(index) * 12.0, -70.0 + float(index) * 8.0))
		mob.hp = 200.0
		volleyed.append(mob)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	await _press.call("skill_2")
	await _finish.call(80)
	var volley_hit := 0
	for mob: Object in volleyed:
		if is_instance_valid(mob) and mob.hp < 200.0:
			volley_hit += 1
	t.assert_true(volley_hit >= 3, "the volley spreads across targets (%d)" % volley_hit)

	# arrow bomb: heavy single-priority damage
	await _clear_mobs.call()
	var bombed: Mob = _spawn_mob.call(Vector2(400.0, -30.0))
	bombed.hp = 500.0
	await t.physics_frame
	await t.physics_frame
	player.level = 5
	player.mana = player.max_mana
	var bomb_hp: float = bombed.hp
	await _press.call("skill_4")
	await _finish.call(80)
	t.assert_true(bomb_hp - bombed.hp >= 40.0, "the arrow bomb hits hard (%d)" % int(bomb_hp - bombed.hp))

	# arrow rain clears a dense pack
	await _clear_mobs.call()
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.level = 20
	player.mana = player.max_mana
	for index in range(20):
		_spawn_mob.call(Vector2(-160.0 + float(index) * 16.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	await _press.call("skill_3")
	await _finish.call(120)
	var survivors := 0
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and not mob.is_dead():
			survivors += 1
	t.assert_eq(survivors, 0, "the arrow rain clears a dense pack (%d survivors)" % survivors)

	# falcon fights for the archer
	await _clear_mobs.call()
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	var dummy: Mob = _spawn_mob.call(Vector2(300.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	await _press.call("skill_5")
	await _finish.call(80)
	t.assert_true(player.active_summons() >= 1, "the archer fields a falcon")
	for _i in range(240):
		await t.physics_frame
		if not is_instance_valid(dummy) or dummy.is_dead():
			break
	t.assert_true(not is_instance_valid(dummy) or dummy.is_dead(), "the falcon fights")

	await _clear_mobs.call()
	for summon: Object in player.get("_summons").duplicate():
		if is_instance_valid(summon):
			summon.queue_free()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
