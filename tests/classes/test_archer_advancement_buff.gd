extends RefCounted

func get_suite_name() -> String:
	return "archer_advancement_buff"

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
	t.assert_eq(archer.advancement_level, 20, "advancement gates at level 20")
	t.assert_eq(archer.advanced_ability_slots.size(), 6, "the advanced artillery is complete")
	t.assert_true(archer.party_crit_bonus > 0.0, "the archer carries a crit aura")
	t.assert_true(archer.party_range_bonus > 0.0, "the archer carries a range aura")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true
	var tactics_events: Array = []
	player.party_tactics_changed.connect(func(crit: float, reach: float): tactics_events.append(Vector2(crit, reach)))
	player.apply_class(archer)

	t.assert_false(player.advanced, "the player starts unadvanced")
	t.assert_eq(player.ability_at(0).id, &"archer_quick_shot", "slot 1 is the quick shot before advancement")
	t.assert_false(player.can_advance(), "advancement is locked below the gate")
	t.assert_false(player.advance(), "advancing early fails")
	t.assert_eq(player.ability_at(0).id, &"archer_quick_shot", "the kit is untouched by a failed advance")

	var aura := player.get_node_or_null("AdvancedAura") as ColorRect
	t.assert_true(aura != null, "the transformation aura exists")
	t.assert_false(aura.visible, "the aura is hidden before advancement")

	var crit_before: float = player.get_crit_chance()
	var speed_before: float = player.run_speed
	player.grant_xp(player.xp_table.xp_for_level(20) - player.xp)
	t.assert_true(player.level >= 20, "granting xp reaches the gate (lv %d)" % player.level)
	t.assert_true(player.can_advance(), "advancement unlocks at the gate")

	var advanced_events: Array = []
	player.class_advanced.connect(func(): advanced_events.append(1))
	t.assert_true(player.advance(), "advancement succeeds at the gate")
	t.assert_true(player.advanced, "the player is advanced")
	t.assert_eq(advanced_events.size(), 1, "advancement emits exactly once")
	t.assert_eq(player.ability_at(0).id, &"archer_rapid_fire", "slot 1 becomes rapid fire")
	t.assert_eq(player.ability_at(1).id, &"archer_storm_volley", "slot 2 becomes the storm volley")
	t.assert_eq(player.ability_at(2).id, &"archer_skyfall", "slot 3 becomes the skyfall barrage")
	t.assert_eq(player.ability_at(3).id, &"archer_demolition", "slot 4 becomes the demolition bolt")
	t.assert_eq(player.ability_at(4).id, &"archer_siege_engine", "slot 5 becomes the siege engine")
	t.assert_eq(player.ability_at(5).id, &"archer_longshot", "slot 6 becomes the longshot")
	t.assert_true(aura.visible, "the transformation aura shows")
	t.assert_eq(player.hp, player.max_hp, "advancement refills hp")
	t.assert_eq(player.get_crit_chance(), crit_before + archer.advanced_crit_bonus,
		"advancement sharpens crit")
	t.assert_true(player.run_speed > speed_before, "advancement quickens movement")
	t.assert_false(player.advance(), "advancement cannot repeat")

	# advanced artillery outguns the bow on paper, at a price
	var rain := load("res://data/abilities/archer_rain.tres") as AbilityDefinition
	var skyfall := load("res://data/abilities/archer_skyfall.tres") as AbilityDefinition
	t.assert_true(skyfall.damage > rain.damage, "the advanced barrage hits harder")
	t.assert_true(skyfall.range > rain.range, "the advanced barrage reaches further")
	t.assert_true(skyfall.mana_cost > rain.mana_cost, "the advanced barrage costs more")
	t.assert_true(skyfall.cast_time > rain.cast_time, "the advanced barrage casts slower")

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

	# rapid fire lives up to its name
	player.global_position = Vector2(300.0, -60.0)
	player.crit_chance = 0.0
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	var rapid_target: Mob = _spawn_mob.call(Vector2(380.0, -40.0))
	rapid_target.hp = 500.0
	await t.physics_frame
	await t.physics_frame
	var rapid_hp: float = rapid_target.hp
	await _press.call("skill_1")
	await _finish.call(60)
	t.assert_true(rapid_target.hp < rapid_hp, "rapid fire damages")
	t.assert_true(rapid_hp - rapid_target.hp >= 15.0, "rapid fire hits in force (%d)" % int(rapid_hp - rapid_target.hp))

	# skyfall clears a dense pack
	await _clear_mobs.call()
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.level = 25
	player.mana = player.max_mana
	for index in range(20):
		_spawn_mob.call(Vector2(-180.0 + float(index) * 18.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	await _press.call("skill_3")
	await _finish.call(120)
	var survivors := 0
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and not mob.is_dead():
			survivors += 1
	t.assert_eq(survivors, 0, "the skyfall barrage clears a dense pack (%d survivors)" % survivors)

	# siege engine fields two engines
	await _clear_mobs.call()
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	player.max_summons = 5
	await _press.call("skill_5")
	await _finish.call(100)
	t.assert_eq(player.active_summons(), 2, "the siege engine fields two engines")
	for summon: Object in player.get("_summons").duplicate():
		if is_instance_valid(summon):
			summon.queue_free()

	# solo aura: crit and reach without any cast
	player.apply_class(archer)
	t.assert_eq(player.effective_tactics_bonus(), Vector2(0.05, 0.15), "the solo aura matches the data")
	t.assert_almost_eq(player.get_crit_chance(), player.crit_chance + 0.05, 0.0001, "the aura sharpens crit")
	t.assert_almost_eq(player.range_multiplier(), 1.15, 0.0001, "the aura lengthens reach")
	t.assert_true(tactics_events.size() >= 1, "applying the class emits the tactics change")

	# reach is real: a mob past base range but inside buffed range is hit
	await _clear_mobs.call()
	player.global_position = Vector2(300.0, -60.0)
	player.crit_chance = 0.0
	await t.physics_frame
	await t.physics_frame
	var base_found: Array = TargetQuery.enemies_in_area(player, 1, 230.0, 60.0, 0, player)
	var edge_target: Mob = _spawn_mob.call(Vector2(300.0 + 250.0, -50.0))
	edge_target.hp = 500.0
	await t.physics_frame
	await t.physics_frame
	var buffed_found: Array = TargetQuery.enemies_in_area(player, 1, 230.0 * player.range_multiplier(), 60.0 * player.range_multiplier(), 0, player)
	t.assert_eq(base_found.size(), 0, "base range misses the distant mob")
	t.assert_true(buffed_found.size() >= 1, "buffed range reaches it")
	player.mana = player.max_mana
	var edge_hp: float = edge_target.hp
	await _press.call("skill_1")
	await _finish.call(60)
	t.assert_true(edge_target.hp < edge_hp, "a live cast lands past base range")

	# simulated party: one archer plus three mages share both bonuses
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	var allies: Array = []
	for index in range(3):
		var ally: Player = load("res://scenes/player/player.tscn").instantiate()
		world.add_child(ally)
		await t.physics_frame
		ally.apply_class(mage)
		ally.global_position = Vector2(100.0 + float(index) * 40.0, -60.0)
		allies.append(ally)
	var roster: Array = [player]
	roster.append_array(allies)
	player.set_party(roster)
	for ally in allies:
		ally.set_party(roster)
	for member in roster:
		t.assert_eq(member.effective_tactics_bonus(), Vector2(0.05, 0.15), "every member sees the tactics")
		t.assert_almost_eq(member.range_multiplier(), 1.15, 0.0001, "every member gains reach")
	t.assert_true(tactics_events.size() >= 1, "the tactics change emits")

	# archer leaves: both bonuses drop automatically
	player.apply_class(mage)
	for member in roster:
		member.refresh_stats()
	t.assert_eq(player.effective_tactics_bonus(), Vector2.ZERO, "no archer means no tactics")
	for ally in allies:
		t.assert_eq(ally.get_crit_chance(), ally.crit_chance, "allies lose the crit bonus too")

	# two archers do not stack
	player.apply_class(archer)
	allies[0].apply_class(archer)
	var duo: Array = [player, allies[0]]
	player.set_party(duo)
	allies[0].set_party(duo)
	t.assert_eq(player.effective_tactics_bonus(), Vector2(0.05, 0.15), "duplicate archers do not stack")

	# advancement survives a save round-trip (re-advance: the buff checks reset it)
	t.assert_true(player.advance(), "re-advancement succeeds for the save check")
	var payload := player.capture_state()
	t.assert_true(payload.advanced, "the save captures advancement")
	var reloaded: Player = load("res://scenes/player/player.tscn").instantiate()
	t.root.add_child(reloaded)
	await t.physics_frame
	await t.physics_frame
	reloaded.restore_state(payload)
	t.assert_eq(reloaded.ability_at(0).id, &"archer_rapid_fire", "the advanced kit survives reload")
	t.assert_true((reloaded.get_node_or_null("AdvancedAura") as ColorRect).visible,
		"the transformation survives reload")

	await _clear_mobs.call()
	for ally in allies:
		if is_instance_valid(ally):
			ally.queue_free()
	reloaded.queue_free()
	player.leave_party()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
