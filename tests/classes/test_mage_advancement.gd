extends RefCounted

func get_suite_name() -> String:
	return "mage_advancement"

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
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	t.assert_true(mage != null, "mage class loads")
	t.assert_eq(mage.advancement_level, 20, "advancement gates at level 20")
	t.assert_eq(mage.advanced_ability_slots.size(), 6, "the advanced kit is complete")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	t.assert_false(player.advanced, "the player starts unadvanced")
	t.assert_eq(player.ability_at(0).id, &"mage_fire", "slot 1 is fire before advancement")
	t.assert_false(player.can_advance(), "advancement is locked below the gate")
	t.assert_false(player.advance(), "advancing early fails")
	t.assert_false(player.advanced, "a failed advance changes nothing")
	t.assert_eq(player.ability_at(0).id, &"mage_fire", "the kit is untouched by a failed advance")

	var aura := player.get_node_or_null("AdvancedAura") as ColorRect
	t.assert_true(aura != null, "the transformation aura exists")
	t.assert_false(aura.visible, "the aura is hidden before advancement")

	player.grant_xp(player.xp_table.xp_for_level(20) - player.xp)
	t.assert_true(player.level >= 20, "granting xp reaches the gate (lv %d)" % player.level)
	t.assert_true(player.can_advance(), "advancement unlocks at the gate")

	var advanced_events: Array = []
	player.class_advanced.connect(func(): advanced_events.append(1))
	t.assert_true(player.advance(), "advancement succeeds at the gate")
	t.assert_true(player.advanced, "the player is advanced")
	t.assert_eq(advanced_events.size(), 1, "advancement emits exactly once")
	t.assert_eq(player.ability_at(0).id, &"mage_steam", "slot 1 becomes the steam hybrid")
	t.assert_eq(player.ability_at(1).id, &"mage_glacier", "slot 2 becomes the glacier")
	t.assert_eq(player.ability_at(2).id, &"mage_chain_lightning", "slot 3 becomes true chain lightning")
	t.assert_eq(player.ability_at(3).id, &"mage_fma_2", "slot 4 becomes the stronger FMA")
	t.assert_eq(player.ability_at(4).id, &"mage_summon_2", "slot 5 becomes the advanced summon")
	t.assert_eq(player.ability_at(5).id, &"mage_mana_shield", "the shield carries over")
	t.assert_true(aura.visible, "the transformation aura shows")
	t.assert_eq(player.hp, player.max_hp, "advancement refills hp")
	t.assert_false(player.advance(), "advancement cannot repeat")
	t.assert_eq(advanced_events.size(), 1, "no second advancement event")

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

	# steam hybrid: damage plus slow from one cast
	player.global_position = Vector2(300.0, -60.0)
	player.crit_chance = 0.0
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	var steam_target: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	steam_target.hp = 200.0
	var steam_hp: float = steam_target.hp
	await _press.call("skill_1")
	await _finish.call(60)
	t.assert_true(steam_target.hp < steam_hp, "the steam hybrid damages")
	t.assert_true(steam_target.is_slowed(), "the steam hybrid slows")

	# chain lightning: ordered jumps with falloff
	await _clear_mobs.call()
	player.mana = player.max_mana
	var struck: Array = []
	EventBus.damage_applied.connect(func(result: DamageResult):
		if result.valid:
			struck.append(result.applied))
	var link_a: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	var link_b: Mob = _spawn_mob.call(Vector2(450.0, -30.0))
	var link_c: Mob = _spawn_mob.call(Vector2(510.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	var struck_before := struck.size()
	await _press.call("skill_3")
	await _finish.call(60)
	var hits: Array = struck.slice(struck_before)
	t.assert_true(hits.size() >= 3, "chain lightning jumps across three mobs (%d)" % hits.size())
	if hits.size() >= 3:
		t.assert_true(hits[0] > hits[1] and hits[1] > hits[2],
			"each jump hits softer than the last (%s)" % str(hits.slice(0, 3)))

	# stronger FMA clears a dense pack
	await _clear_mobs.call()
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.level = 25
	player.mana = player.max_mana
	for index in range(20):
		_spawn_mob.call(Vector2(-160.0 + float(index) * 16.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	await _press.call("skill_4")
	await _finish.call(100)
	var survivors := 0
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and not mob.is_dead():
			survivors += 1
	t.assert_eq(survivors, 0, "the stronger FMA clears a dense pack (%d survivors)" % survivors)

	# advanced summon fields three wisps
	await _clear_mobs.call()
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	player.max_summons = 5
	await _press.call("skill_5")
	await _finish.call(80)
	t.assert_eq(player.active_summons(), 3, "the advanced summon fields three wisps")
	for summon: Object in player.get("_summons").duplicate():
		if is_instance_valid(summon):
			summon.queue_free()

	# advancement survives a save round-trip
	var payload := player.capture_state()
	t.assert_true(payload.advanced, "the save captures advancement")
	var reloaded: Player = load("res://scenes/player/player.tscn").instantiate()
	t.root.add_child(reloaded)
	await t.physics_frame
	await t.physics_frame
	reloaded.restore_state(payload)
	t.assert_true(reloaded.advanced, "advancement survives reload")
	t.assert_eq(reloaded.ability_at(0).id, &"mage_steam", "the advanced kit survives reload")
	t.assert_true((reloaded.get_node_or_null("AdvancedAura") as ColorRect).visible,
		"the transformation survives reload")

	await _clear_mobs.call()
	reloaded.queue_free()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
