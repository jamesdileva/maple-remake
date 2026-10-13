extends RefCounted

const FMA_IDS := {
	&"mage": &"mage_fma",
	&"warrior": &"warrior_quake",
	&"archer": &"archer_rain",
	&"assassin": &"assassin_eclipse",
}
const FMA_ACTIONS := {
	&"mage": "skill_4",
	&"warrior": "skill_4",
	&"archer": "skill_3",
	&"assassin": "skill_4",
}

func get_suite_name() -> String:
	return "power_budget"

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
	var classes := {
		&"mage": load("res://data/classes/mage.tres") as ClassDefinition,
		&"warrior": load("res://data/classes/warrior.tres") as ClassDefinition,
		&"archer": load("res://data/classes/archer.tres") as ClassDefinition,
		&"assassin": load("res://data/classes/assassin.tres") as ClassDefinition,
	}
	for id in classes:
		t.assert_true(classes[id] != null, "the %s definition loads" % String(id))

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	t.assert_true(classes[&"warrior"].starting_hp > classes[&"archer"].starting_hp, "bulk order: warrior outlasts archer")
	t.assert_true(classes[&"archer"].starting_hp > classes[&"assassin"].starting_hp, "bulk order: archer outlasts assassin")
	t.assert_true(classes[&"assassin"].starting_hp > classes[&"mage"].starting_hp, "bulk order: assassin outlasts mage")
	t.assert_true(classes[&"warrior"].defense > classes[&"archer"].defense, "mitigation order: warrior over archer")
	t.assert_true(classes[&"archer"].defense > classes[&"assassin"].defense, "mitigation order: archer over assassin")
	t.assert_true(classes[&"assassin"].defense > classes[&"mage"].defense, "mitigation order: assassin over mage")
	t.assert_true(classes[&"assassin"].crit_chance > classes[&"archer"].crit_chance, "precision order: assassin crits most")
	t.assert_true(classes[&"archer"].crit_chance > classes[&"mage"].crit_chance, "precision order: archer over mage")

	var cheapest := 999999.0
	var priciest := 0.0
	var quickest := 999999.0
	var slowest := 0.0
	var weakest := 999999.0
	for id in classes:
		var fma := load("res://data/abilities/%s.tres" % String(FMA_IDS[id])) as AbilityDefinition
		t.assert_true(fma.damage >= 40.0, "the %s FMA one-shots a 30 HP slime on paper" % String(id))
		cheapest = minf(cheapest, fma.mana_cost)
		priciest = maxf(priciest, fma.mana_cost)
		quickest = minf(quickest, fma.cast_time)
		slowest = maxf(slowest, fma.cast_time)
		weakest = minf(weakest, fma.damage)
	t.assert_true(priciest / cheapest <= 1.5, "FMA mana costs stay within one budget (%.0f vs %.0f)" % [priciest, cheapest])
	t.assert_true(slowest / quickest <= 1.5, "FMA cast times stay within one budget (%.2f vs %.2f)" % [slowest, quickest])
	t.assert_true(weakest >= 40.0, "the weakest FMA still clears chaff (%.0f)" % weakest)

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")

	var _clear_mobs = func() -> void:
		for mob: Object in t.get_nodes_in_group("enemies"):
			if is_instance_valid(mob):
				mob.queue_free()
		await t.physics_frame

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

	player.set_level(20)
	player.mana_regen_per_second = 0.0
	var results := {}
	for id in classes:
		await _clear_mobs.call()
		player.apply_class(classes[id])
		player.crit_chance = 0.0
		player.global_position = Vector2(0.0, -60.0)
		player.hp = player.max_hp
		player.mana = player.max_mana
		await t.physics_frame
		await t.physics_frame
		for index in range(20):
			var mob: Mob = mob_scene.instantiate()
			mob.definition = definition
			mob.global_position = Vector2(-160.0 + float(index) * 16.0, -30.0)
			world.add_child(mob)
		await t.physics_frame
		await t.physics_frame
		var mana_before: float = player.mana
		await _press.call(FMA_ACTIONS[id])
		await _finish.call(150)
		var survivors := 0
		for mob: Object in t.get_nodes_in_group("enemies"):
			if is_instance_valid(mob) and not mob.is_dead():
				survivors += 1
		results[id] = {"survivors": survivors, "spent": mana_before - player.mana}
	for id in results:
		t.assert_eq(results[id]["survivors"], 0, "the %s FMA clears an identical 20-pack" % String(id))
		t.assert_true(results[id]["spent"] > 0.0, "the %s FMA is constrained by mana, not cooldown" % String(id))

	player.apply_class(classes[&"warrior"])
	var warrior_hp: float = player.max_hp
	player.hp = warrior_hp
	DebugManager.god_mode = false
	player.take_damage(20.0, null)
	var warrior_share := (warrior_hp - player.hp) / warrior_hp
	player.apply_class(classes[&"mage"])
	var mage_hp: float = player.max_hp
	player.hp = mage_hp
	player.take_damage(20.0, null)
	var mage_share := (mage_hp - player.hp) / mage_hp
	DebugManager.god_mode = true
	t.assert_true(warrior_share < mage_share, "the same hit costs the warrior less (%.3f vs %.3f)" % [warrior_share, mage_share])

	await _clear_mobs.call()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
