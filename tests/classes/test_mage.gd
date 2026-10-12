extends RefCounted

func get_suite_name() -> String:
	return "mage_class"

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
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	t.assert_true(mage != null, "mage class definition loads from data")
	t.assert_eq(mage.id, &"mage", "the mage declares its id")
	t.assert_eq(mage.display_name, "Mage", "the mage declares its name")
	t.assert_true(player.class_definition != null, "the player carries a class")
	t.assert_eq(player.class_definition.id, &"mage", "the player is a mage")

	var slots := mage.ability_slots
	t.assert_eq(slots.size(), 6, "the mage has six abilities")
	var elements := []
	for ability: AbilityDefinition in slots:
		if ability != null:
			elements.append(ability.element)
	t.assert_true(elements.has(AbilityDefinition.Element.FIRE), "the mage has a fire ability")
	t.assert_true(elements.has(AbilityDefinition.Element.ICE), "the mage has an ice ability")
	t.assert_true(elements.has(AbilityDefinition.Element.LIGHTNING), "the mage has a lightning ability")
	t.assert_true(player.ability_at(0) != null and player.ability_at(1) != null and player.ability_at(2) != null,
		"elemental attacks are slottable 1-3")
	t.assert_true(player.ability_at(3).area_mode == AbilityDefinition.AreaMode.CENTERED, "the FMA is a centered area attack")
	t.assert_true(player.ability_at(4).is_summon(), "slot 5 is a summon")
	t.assert_true(player.ability_at(5).is_shield(), "slot 6 is a mana shield")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

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

	# fire: single target, high damage
	player.mana = player.max_mana
	player.crit_chance = 0.0
	var fire_target: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	var fire_hp: float = fire_target.hp
	var fire_mana: float = player.mana
	await _press.call("skill_1")
	t.assert_true(player.is_casting(), "fire bolt casts")
	await _finish.call(60)
	t.assert_true(fire_target.hp < fire_hp, "fire bolt damages its target")
	t.assert_true(player.mana < fire_mana, "fire bolt spends mana")

	# ice: slows what it hits
	await _clear_mobs.call()
	var ice_target: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	var ice_hp: float = ice_target.hp
	var position_before: float = ice_target.global_position.x
	await _press.call("skill_2")
	await _finish.call(60)
	t.assert_true(ice_target.hp < ice_hp, "frost shard damages its target")
	t.assert_true(ice_target.is_slowed(), "frost shard slows its target")
	var speed_scale := 1.0
	for _i in range(6):
		await t.physics_frame
	t.assert_true(absf(ice_target.global_position.x - position_before) <= 1.0,
		"a slowed mob barely moves while slowed")

	# lightning: multi target
	await _clear_mobs.call()
	var bolt_a: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	var bolt_b: Mob = _spawn_mob.call(Vector2(420.0, -60.0))
	await t.physics_frame
	await t.physics_frame
	player.level = 5
	player.mana = player.max_mana
	var bolt_a_hp: float = bolt_a.hp
	var bolt_b_hp: float = bolt_b.hp
	await _press.call("skill_3")
	await _finish.call(60)
	t.assert_true(bolt_a.hp < bolt_a_hp and bolt_b.hp < bolt_b_hp,
		"chain spark hits multiple targets")
	player.crit_chance = 0.05

	# mana shield absorbs damage
	player.mana = player.max_mana
	player.hp = player.max_hp
	var hp_before: float = player.hp
	DebugManager.god_mode = false
	await _press.call("skill_6")
	await _finish.call(40)
	t.assert_true(player.is_shielded(), "mana shield is active after casting")
	t.assert_true(player.shield_hp() > 0.0, "the shield reports its absorb pool")
	player.take_damage(25.0, null)
	t.assert_eq(player.hp, hp_before, "the shield absorbs damage without touching hp")
	t.assert_true(player.shield_hp() > 0.0, "the shield drains instead of hp")
	player.take_damage(999999.0, null)
	t.assert_false(player.is_shielded(), "the shield is consumed by a lethal hit")
	t.assert_true(player.hp <= hp_before, "damage beyond the shield reaches hp")
	DebugManager.god_mode = true

	# summon fights for you
	await _clear_mobs.call()
	player.mana = player.max_mana
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	var dummy: Mob = _spawn_mob.call(Vector2(300.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	var dummy_hp: float = dummy.hp
	t.assert_eq(player.active_summons(), 0, "no summons before casting")
	await _press.call("skill_5")
	await _finish.call(60)
	t.assert_true(player.active_summons() >= 1, "the summon ability spawns allies")
	dummy.take_damage(15.0, null)
	for _i in range(240):
		await t.physics_frame
		if not is_instance_valid(dummy) or dummy.is_dead():
			break
	t.assert_true(not is_instance_valid(dummy) or dummy.is_dead(),
		"a summon damages enemies")

	# FMA clears a dense pack
	await _clear_mobs.call()
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	var pack: Array = []
	for index in range(20):
		var mob: Mob = _spawn_mob.call(Vector2(-140.0 + float(index) * 14.0, -30.0))
		pack.append(mob)
	await t.physics_frame
	await t.physics_frame
	player.level = 10
	player.mana = player.max_mana
	await _press.call("skill_4")
	await _finish.call(90)
	var survivors := 0
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and not mob.is_dead():
			survivors += 1
	t.assert_eq(survivors, 0, "the FMA clears a dense mob pack (%d survivors)" % survivors)
	t.assert_true(player.mana > 0.0, "the player survives the fight with mana left")

	await _clear_mobs.call()
	for summon: Object in player.get("_summons").duplicate():
		if is_instance_valid(summon):
			summon.queue_free()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
