extends RefCounted

func get_suite_name() -> String:
	return "assassin_advancement"

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
	t.assert_true(assassin != null, "assassin class loads")
	t.assert_eq(assassin.advancement_level, 20, "advancement gates at level 20")
	t.assert_eq(assassin.advanced_ability_slots.size(), 6, "the advanced kit is complete")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	player.apply_class(assassin)
	t.assert_false(player.advanced, "the player starts unadvanced")
	t.assert_eq(player.ability_at(0).id, &"assassin_strike", "slot 1 is the dagger strike before advancement")
	t.assert_false(player.can_advance(), "advancement is locked below the gate")
	t.assert_false(player.advance(), "advancing early fails")
	t.assert_false(player.advanced, "a failed advance changes nothing")
	t.assert_eq(player.ability_at(0).id, &"assassin_strike", "the kit is untouched by a failed advance")

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
	t.assert_eq(player.ability_at(0).id, &"assassin_execution", "slot 1 becomes the execution")
	t.assert_eq(player.ability_at(1).id, &"assassin_blink", "slot 2 becomes the blink backstab")
	t.assert_eq(player.ability_at(2).id, &"assassin_arsenal", "slot 3 becomes the shadow arsenal")
	t.assert_eq(player.ability_at(3).id, &"assassin_nightmare", "slot 4 becomes the clone nightmare")
	t.assert_eq(player.ability_at(4).id, &"assassin_legion", "slot 5 becomes the shadow legion")
	t.assert_eq(player.ability_at(5).id, &"assassin_reaper", "slot 6 becomes the reaper")
	t.assert_true(aura.visible, "the transformation aura shows")
	t.assert_eq(player.hp, player.max_hp, "advancement refills hp")
	t.assert_eq(player.get_defense(), defense_before + assassin.advanced_defense_bonus,
		"advancement hardens defense")
	t.assert_eq(player.get_crit_chance(), crit_before + assassin.advanced_crit_bonus,
		"advancement sharpens crit")
	t.assert_true(player.run_speed > speed_before, "advancement quickens movement")
	t.assert_false(player.advance(), "advancement cannot repeat")
	t.assert_eq(advanced_events.size(), 1, "no second advancement event")

	var execution := load("res://data/abilities/assassin_execution.tres") as AbilityDefinition
	var blink := load("res://data/abilities/assassin_blink.tres") as AbilityDefinition
	var arsenal := load("res://data/abilities/assassin_arsenal.tres") as AbilityDefinition
	var nightmare := load("res://data/abilities/assassin_nightmare.tres") as AbilityDefinition
	var eclipse := load("res://data/abilities/assassin_eclipse.tres") as AbilityDefinition
	var dash := load("res://data/abilities/assassin_dash.tres") as AbilityDefinition
	var strike := load("res://data/abilities/assassin_strike.tres") as AbilityDefinition
	var reaper := load("res://data/abilities/assassin_reaper.tres") as AbilityDefinition
	t.assert_true(execution.boss_multiplier > 1.0, "execution punishes tough targets")
	t.assert_true(reaper.boss_multiplier > 1.0, "the reaper punishes tough targets")
	t.assert_true(arsenal.chain_jumps > 0, "the arsenal introduces chained shadow weapons")
	t.assert_true(blink.range > dash.range, "teleport outranges the base dash")
	t.assert_true(nightmare.range > eclipse.range, "the clone FMA reaches further")

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
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	var execution_target: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	execution_target.hp = 500.0
	var execution_hp: float = execution_target.hp
	await _press.call("skill_1")
	await _finish.call(80)
	var execution_dealt := execution_hp - execution_target.hp
	t.assert_true(execution_dealt > 60.0, "execution hits like an executioner (%d)" % int(execution_dealt))
	t.assert_true(execution_dealt > strike.damage_at(player.ability_level(strike)),
		"the advanced execution clearly beats the base strike")

	await _clear_mobs.call()
	player.mana = player.max_mana
	var far_target: Mob = _spawn_mob.call(Vector2(600.0, -30.0))
	far_target.hp = 500.0
	await t.physics_frame
	await t.physics_frame
	var far_hp: float = far_target.hp
	await _press.call("skill_2")
	await _finish.call(60)
	t.assert_true(far_target.hp < far_hp, "the blink backstab teleports to distant targets")

	await _clear_mobs.call()
	player.mana = player.max_mana
	var struck: Array = []
	var on_hit := func(result: DamageResult):
		if result.valid:
			struck.append(result.applied)
	EventBus.damage_applied.connect(on_hit)
	var link_a: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	var link_b: Mob = _spawn_mob.call(Vector2(450.0, -30.0))
	var link_c: Mob = _spawn_mob.call(Vector2(510.0, -30.0))
	link_a.hp = 400.0
	link_b.hp = 400.0
	link_c.hp = 400.0
	await t.physics_frame
	await t.physics_frame
	var struck_before := struck.size()
	await _press.call("skill_3")
	await _finish.call(80)
	var hits: Array = struck.slice(struck_before)
	t.assert_true(hits.size() >= 3, "shadow weapons jump across three mobs (%d)" % hits.size())
	if hits.size() >= 3:
		t.assert_true(hits[0] > hits[1] and hits[1] > hits[2],
			"each weapon hits softer than the last (%s)" % str(hits.slice(0, 3)))
	EventBus.damage_applied.disconnect(on_hit)

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
	t.assert_eq(survivors, 0, "the clone nightmare clears a dense pack (%d survivors)" % survivors)

	await _clear_mobs.call()
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	player.max_summons = 5
	await _press.call("skill_5")
	await _finish.call(100)
	t.assert_eq(player.active_summons(), 2, "the legion fields two shades")
	for summon: Object in player.get("_summons").duplicate():
		if is_instance_valid(summon):
			summon.queue_free()

	await _clear_mobs.call()
	player.mana = player.max_mana
	var reaper_target: Mob = _spawn_mob.call(Vector2(370.0, -30.0))
	reaper_target.hp = 800.0
	await t.physics_frame
	await t.physics_frame
	var reaper_hp: float = reaper_target.hp
	await _press.call("skill_6")
	await _finish.call(80)
	var reaper_dealt := reaper_hp - reaper_target.hp
	t.assert_true(reaper_dealt > 100.0, "the reaper ends targets (%d)" % int(reaper_dealt))

	t.assert_true(nightmare.damage > eclipse.damage, "the advanced FMA hits harder")
	t.assert_true(nightmare.mana_cost > eclipse.mana_cost, "the advanced FMA costs more")
	t.assert_true(nightmare.cast_time > eclipse.cast_time, "the advanced FMA casts slower")

	var payload := player.capture_state()
	t.assert_true(payload.advanced, "the save captures advancement")
	var reloaded: Player = load("res://scenes/player/player.tscn").instantiate()
	t.root.add_child(reloaded)
	await t.physics_frame
	await t.physics_frame
	reloaded.restore_state(payload)
	t.assert_true(reloaded.advanced, "advancement survives reload")
	t.assert_eq(reloaded.ability_at(0).id, &"assassin_execution", "the advanced kit survives reload")
	t.assert_true((reloaded.get_node_or_null("AdvancedAura") as ColorRect).visible,
		"the transformation survives reload")

	await _clear_mobs.call()
	reloaded.queue_free()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
