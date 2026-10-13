extends RefCounted

func get_suite_name() -> String:
	return "assassin_class"

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
	var assassin: ClassDefinition = load("res://data/classes/assassin.tres")
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	var warrior: ClassDefinition = load("res://data/classes/warrior.tres")
	var archer: ClassDefinition = load("res://data/classes/archer.tres")
	t.assert_true(assassin != null, "assassin class definition loads from data")
	t.assert_eq(assassin.id, &"assassin", "the assassin declares its id")
	t.assert_eq(assassin.display_name, "Assassin", "the assassin declares its name")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	t.assert_true(assassin.starting_hp > mage.starting_hp, "the assassin is sturdier than the mage")
	t.assert_true(assassin.starting_hp < warrior.starting_hp, "the assassin trades bulk for speed")
	t.assert_true(assassin.defense < warrior.defense, "the assassin relies on mobility, not armor")
	t.assert_true(assassin.crit_chance > archer.crit_chance, "the executioner crits most often")
	t.assert_true(assassin.base_speed_bonus > 0.0, "the assassin carries a base speed bonus")
	t.assert_true(assassin.advanced_ability_slots.size() == 6, "the advanced kit is complete")

	player.apply_class(assassin)
	t.assert_eq(player.max_hp, assassin.starting_hp + _equipment_hp(player), "the assassin kit HP applies")
	t.assert_eq(player.get_defense(), assassin.defense + _equipment_defense(player), "the assassin mitigation is active")
	t.assert_true(player.run_speed > 280.0, "the assassin moves faster than the base speed (%.1f)" % player.run_speed)

	var mage_probe: Player = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(mage_probe)
	await t.physics_frame
	await t.physics_frame
	mage_probe.apply_class(mage)
	t.assert_true(player.run_speed > mage_probe.run_speed, "mobility feels immediately different from the mage")
	mage_probe.apply_class(warrior)
	t.assert_true(player.run_speed > mage_probe.run_speed, "mobility feels immediately different from the warrior")
	mage_probe.apply_class(archer)
	t.assert_true(player.run_speed > mage_probe.run_speed, "mobility feels immediately different from the archer")
	mage_probe.queue_free()
	player.apply_class(assassin)

	var slots := assassin.ability_slots
	t.assert_eq(slots.size(), 6, "the assassin has six slots")
	var non_null := 0
	var slowest := 0.0
	for ability: AbilityDefinition in slots:
		if ability == null:
			continue
		non_null += 1
		slowest = maxf(slowest, ability.cast_time)
	t.assert_eq(non_null, 5, "the dagger kit fills five slots")
	t.assert_true(slowest <= 0.7, "the whole kit casts fast (slowest %.2fs)" % slowest)
	t.assert_eq(player.ability_at(0).id, &"assassin_strike", "slot 1 is the dagger strike")
	t.assert_eq(player.ability_at(1).id, &"assassin_dash", "slot 2 is the shadow dash")
	t.assert_eq(player.ability_at(2).id, &"assassin_shroud", "slot 3 is the shadow shroud")
	t.assert_eq(player.ability_at(3).id, &"assassin_eclipse", "slot 4 is the eclipse FMA")
	t.assert_true(player.ability_at(3).area_mode == AbilityDefinition.AreaMode.CENTERED, "the eclipse is a centered blast")
	t.assert_true(player.ability_at(4).is_summon(), "slot 5 is a shade summon")
	t.assert_eq(player.ability_at(5), null, "slot 6 is empty for advancement")
	t.assert_true(player.ability_at(0).max_targets <= 2, "the dagger strike stays melee-scoped")
	t.assert_true(player.ability_at(0).range < 200.0, "the dagger strike is a melee reach")
	t.assert_true(player.ability_at(1).range > 250.0, "the dash lunges past melee")

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

	player.mana = player.max_mana
	var target: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	target.hp = 200.0
	await t.physics_frame
	await t.physics_frame
	var hp_before: float = target.hp
	var mana_before: float = player.mana
	await _press.call("skill_1")
	await _finish.call(60)
	t.assert_true(target.hp < hp_before, "the dagger strike damages")
	t.assert_true(mana_before - player.mana <= 8.0, "the dagger strike is cheap")

	await _clear_mobs.call()
	player.mana = player.max_mana
	var far_target: Mob = _spawn_mob.call(Vector2(520.0, -30.0))
	far_target.hp = 300.0
	await t.physics_frame
	await t.physics_frame
	var far_hp: float = far_target.hp
	await _press.call("skill_2")
	await _finish.call(60)
	t.assert_true(far_target.hp < far_hp, "the shadow dash reaches distant targets")

	await _clear_mobs.call()
	var shrouded: Array = []
	for index in range(5):
		var mob: Mob = _spawn_mob.call(Vector2(380.0 + float(index) * 12.0, -70.0 + float(index) * 8.0))
		mob.hp = 200.0
		shrouded.append(mob)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	await _press.call("skill_3")
	await _finish.call(80)
	var shroud_hit := 0
	for mob: Object in shrouded:
		if is_instance_valid(mob) and mob.hp < 200.0:
			shroud_hit += 1
	t.assert_true(shroud_hit >= 3, "the shroud spreads across targets (%d)" % shroud_hit)

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
	await _press.call("skill_4")
	await _finish.call(120)
	var survivors := 0
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and not mob.is_dead():
			survivors += 1
	t.assert_eq(survivors, 0, "the eclipse clears a dense pack (%d survivors)" % survivors)

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
	t.assert_true(player.active_summons() >= 1, "the assassin fields a shade")
	for _i in range(240):
		await t.physics_frame
		if not is_instance_valid(dummy) or dummy.is_dead():
			break
	t.assert_true(not is_instance_valid(dummy) or dummy.is_dead(), "the shade fights")

	await _clear_mobs.call()
	for summon: Object in player.get("_summons").duplicate():
		if is_instance_valid(summon):
			summon.queue_free()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _equipment_hp(player: Player) -> float:
	var total := 0.0
	for slot_name in player.equipment:
		var item: EquipmentDefinition = player.equipment[slot_name]
		if item != null:
			total += item.max_hp_bonus
	return total

func _equipment_defense(player: Player) -> float:
	var total := 0.0
	for slot_name in player.equipment:
		var item: EquipmentDefinition = player.equipment[slot_name]
		if item != null:
			total += item.defense_bonus
	return total
