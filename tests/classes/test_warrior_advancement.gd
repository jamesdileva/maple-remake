extends RefCounted

func get_suite_name() -> String:
	return "warrior_advancement"

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
	t.assert_true(warrior != null, "warrior class loads")
	t.assert_eq(warrior.advancement_level, 20, "advancement gates at level 20")
	t.assert_eq(warrior.advanced_ability_slots.size(), 6, "the advanced kit is complete")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	player.apply_class(warrior)
	t.assert_false(player.advanced, "the player starts unadvanced")
	t.assert_eq(player.ability_at(0).id, &"warrior_heavy_slash", "slot 1 is the heavy slash before advancement")
	t.assert_false(player.can_advance(), "advancement is locked below the gate")
	t.assert_false(player.advance(), "advancing early fails")
	t.assert_false(player.advanced, "a failed advance changes nothing")
	t.assert_eq(player.ability_at(0).id, &"warrior_heavy_slash", "the kit is untouched by a failed advance")

	var aura := player.get_node_or_null("AdvancedAura") as ColorRect
	t.assert_true(aura != null, "the transformation aura exists")
	t.assert_false(aura.visible, "the aura is hidden before advancement")

	var defense_before: float = player.get_defense()
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
	t.assert_eq(player.ability_at(0).id, &"warrior_cleave", "slot 1 becomes the juggernaut cleave")
	t.assert_eq(player.ability_at(1).id, &"warrior_stone_skin", "slot 2 becomes stone skin")
	t.assert_eq(player.ability_at(2).id, &"warrior_blitz", "slot 3 becomes the blitz rush")
	t.assert_eq(player.ability_at(3).id, &"warrior_earthquake", "slot 4 becomes the earthquake")
	t.assert_eq(player.ability_at(4).id, &"warrior_warhost", "slot 5 becomes the warhost")
	t.assert_eq(player.ability_at(5).id, &"warrior_colossus", "slot 6 becomes the colossus slam")
	t.assert_true(aura.visible, "the transformation aura shows")
	t.assert_eq(player.hp, player.max_hp, "advancement refills hp")
	t.assert_eq(player.get_defense(), defense_before + warrior.advanced_defense_bonus,
		"advancement hardens defense")
	t.assert_eq(player.get_crit_chance(), crit_before + warrior.advanced_crit_bonus,
		"advancement sharpens crit")
	t.assert_true(player.run_speed > speed_before, "advancement quickens movement")
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

	# cleave out-damages the base slash
	player.global_position = Vector2(300.0, -60.0)
	player.crit_chance = 0.0
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	var cleave_target: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	cleave_target.hp = 500.0
	var cleave_hp: float = cleave_target.hp
	await _press.call("skill_1")
	await _finish.call(80)
	var cleave_dealt := cleave_hp - cleave_target.hp
	t.assert_true(cleave_dealt > 40.0, "the cleave hits like a juggernaut (%d)" % int(cleave_dealt))
	var slash := load("res://data/abilities/warrior_heavy_slash.tres") as AbilityDefinition
	t.assert_true(cleave_dealt > slash.damage_at(player.ability_level(slash)),
		"the advanced strike clearly beats the base strike")

	# stone skin absorbs without touching hp
	player.hp = player.max_hp
	var hp_before: float = player.hp
	player.mana = player.max_mana
	await _press.call("skill_2")
	await _finish.call(60)
	t.assert_true(player.is_shielded(), "stone skin raises a guard")
	player.take_damage(40.0, null)
	t.assert_eq(player.hp, hp_before, "the guard absorbs without touching hp")

	# blitz rush reaches far targets fast
	await _clear_mobs.call()
	player.mana = player.max_mana
	var far_target: Mob = _spawn_mob.call(Vector2(520.0, -30.0))
	far_target.hp = 500.0
	await t.physics_frame
	await t.physics_frame
	var far_hp: float = far_target.hp
	await _press.call("skill_3")
	await _finish.call(60)
	t.assert_true(far_target.hp < far_hp, "the blitz rush reaches distant targets")

	# earthquake clears a dense pack
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
	await _press.call("skill_4")
	await _finish.call(120)
	var survivors := 0
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and not mob.is_dead():
			survivors += 1
	t.assert_eq(survivors, 0, "the earthquake clears a dense pack (%d survivors)" % survivors)

	# warhost fields two shieldbearers
	await _clear_mobs.call()
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	player.max_summons = 5
	await _press.call("skill_5")
	await _finish.call(100)
	t.assert_eq(player.active_summons(), 2, "the warhost fields two shieldbearers")
	for summon: Object in player.get("_summons").duplicate():
		if is_instance_valid(summon):
			summon.queue_free()

	# advancement trades power for cost: not objectively superior
	var quake := load("res://data/abilities/warrior_quake.tres") as AbilityDefinition
	var earthquake := load("res://data/abilities/warrior_earthquake.tres") as AbilityDefinition
	t.assert_true(earthquake.damage > quake.damage, "the advanced FMA hits harder")
	t.assert_true(earthquake.mana_cost > quake.mana_cost, "the advanced FMA costs more")
	t.assert_true(earthquake.cast_time > quake.cast_time, "the advanced FMA casts slower")

	# advancement survives a save round-trip
	var payload := player.capture_state()
	t.assert_true(payload.advanced, "the save captures advancement")
	var reloaded: Player = load("res://scenes/player/player.tscn").instantiate()
	t.root.add_child(reloaded)
	await t.physics_frame
	await t.physics_frame
	reloaded.restore_state(payload)
	t.assert_true(reloaded.advanced, "advancement survives reload")
	t.assert_eq(reloaded.ability_at(0).id, &"warrior_cleave", "the advanced kit survives reload")
	t.assert_true((reloaded.get_node_or_null("AdvancedAura") as ColorRect).visible,
		"the transformation survives reload")

	await _clear_mobs.call()
	reloaded.queue_free()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
