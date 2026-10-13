extends RefCounted

func get_suite_name() -> String:
	return "warrior_class"

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
	var warrior: ClassDefinition = load("res://data/classes/warrior.tres")
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	t.assert_true(warrior != null, "warrior class definition loads from data")
	t.assert_eq(warrior.id, &"warrior", "the warrior declares its id")
	t.assert_eq(warrior.display_name, "Warrior", "the warrior declares its name")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	t.assert_true(warrior.starting_hp > mage.starting_hp, "the warrior has far more HP than the mage")
	t.assert_true(warrior.defense > mage.defense, "the warrior has real mitigation")
	t.assert_true(warrior.starting_mana < mage.starting_mana, "the warrior trades mana for durability")
	t.assert_true(warrior.advanced_ability_slots.size() == 6 or warrior.advanced_ability_slots.is_empty(),
		"the advanced kit is either complete or absent, never partial")

	player.apply_class(warrior)
	t.assert_eq(player.max_hp, warrior.starting_hp + _equipment_hp(player) + warrior.party_hp_bonus,
		"the warrior kit HP applies, aura included")
	t.assert_eq(player.get_defense(), warrior.defense + _equipment_defense(player),
		"the warrior mitigation is active")

	var slots := warrior.ability_slots
	t.assert_eq(slots.size(), 6, "the warrior has six slots")
	var elements := []
	for ability: AbilityDefinition in slots:
		if ability != null:
			elements.append(ability.element)
	t.assert_true(elements.has(AbilityDefinition.Element.NONE),
		"the warrior is not an elemental class")
	t.assert_eq(player.ability_at(0).id, &"warrior_heavy_slash", "slot 1 is the heavy strike")
	t.assert_eq(player.ability_at(1).id, &"warrior_shield_bash", "slot 2 is the shield bash")
	t.assert_eq(player.ability_at(2).id, &"warrior_whirlwind", "slot 3 is the whirlwind")
	t.assert_eq(player.ability_at(3).id, &"warrior_quake", "slot 4 is the FMA")
	t.assert_true(player.ability_at(3).area_mode == AbilityDefinition.AreaMode.CENTERED,
		"the warrior FMA is a centered blast")
	t.assert_true(player.ability_at(4).is_summon(), "slot 5 is a summon")
	t.assert_eq(player.ability_at(5), null, "slot 6 is empty for now")
	t.assert_true(player.ability_at(0).max_targets <= 2, "the heavy strike stays melee-scoped")
	t.assert_true(player.ability_at(0).range < 200.0, "the heavy strike is a melee reach")

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

	player.global_position = Vector2(300.0, -60.0)
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0
	await t.physics_frame
	await t.physics_frame

	# heavy strike: melee single-target
	player.mana = player.max_mana
	var target: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	target.hp = 200.0
	await t.physics_frame
	await t.physics_frame
	var hp_before: float = target.hp
	var mana_before: float = player.mana
	await _press.call("skill_1")
	await _finish.call(60)
	t.assert_true(target.hp < hp_before, "the heavy strike damages")
	t.assert_true(player.mana < mana_before, "the heavy strike spends stamina")

	# shield bash: slow on hit
	var bashed: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	bashed.hp = 200.0
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	await _press.call("skill_2")
	await _finish.call(60)
	t.assert_true(is_instance_valid(bashed) and bashed.is_slowed(), "the shield bash slows its target")

	# whirlwind: wide multi-target
	await _clear_mobs.call()
	var whirled: Array = []
	for index in range(5):
		var mob: Mob = _spawn_mob.call(Vector2(360.0 + float(index) * 12.0, -30.0))
		mob.hp = 200.0
		whirled.append(mob)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	await _press.call("skill_3")
	await _finish.call(80)
	var whirled_hit := 0
	for mob: Object in whirled:
		if is_instance_valid(mob) and mob.hp < 200.0:
			whirled_hit += 1
	t.assert_true(whirled_hit >= 3, "the whirlwind sweeps several targets (%d)" % whirled_hit)

	# FMA clears a dense pack
	await _clear_mobs.call()
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.level = 20
	player.mana = player.max_mana
	var pack: Array = []
	for index in range(20):
		var mob: Mob = _spawn_mob.call(Vector2(-160.0 + float(index) * 16.0, -30.0))
		pack.append(mob)
	await t.physics_frame
	await t.physics_frame
	await _press.call("skill_4")
	await _finish.call(120)
	var survivors := 0
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and not mob.is_dead():
			survivors += 1
	t.assert_eq(survivors, 0, "the warrior FMA clears a dense pack (%d survivors)" % survivors)

	# summon fights for the warrior
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
	t.assert_true(player.active_summons() >= 1, "the warrior fields a steady shieldbearer")
	for _i in range(240):
		await t.physics_frame
		if not is_instance_valid(dummy) or dummy.is_dead():
			break
	t.assert_true(not is_instance_valid(dummy) or dummy.is_dead(), "the shieldbearer fights")

	# mitigation is measurably better than the mage
	player.apply_class(warrior)
	var mage_player: Player = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(mage_player)
	await t.physics_frame
	await t.physics_frame
	mage_player.apply_class(mage)
	var warrior_defense: float = player.get_defense()
	var mage_defense: float = mage_player.get_defense()
	t.assert_true(warrior_defense > mage_defense,
		"the warrior mitigates more than the mage (%d vs %d)" % [int(warrior_defense), int(mage_defense)])
	player.hp = player.max_hp
	mage_player.hp = mage_player.max_hp
	DebugManager.god_mode = false
	var warrior_share: float = _damage_share(player, 20.0)
	var mage_share: float = _damage_share(mage_player, 20.0)
	DebugManager.god_mode = true
	t.assert_true(warrior_share < mage_share,
		"the same hit costs the warrior a smaller share of max HP (%.3f vs %.3f)" % [warrior_share, mage_share])
	mage_player.queue_free()

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

func _damage_share(player: Player, amount: float) -> float:
	var hp_before: float = player.hp
	player.take_damage(amount, null)
	if player.max_hp <= 0.0:
		return 0.0
	return (hp_before - player.hp) / player.max_hp
