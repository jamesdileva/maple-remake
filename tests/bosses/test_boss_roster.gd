extends RefCounted

const BOSSES := {
	&"mawroot": {"level": 14, "phases": 2},
	&"forge_warden": {"level": 18, "phases": 2},
	&"blightheart": {"level": 28, "phases": 3},
}
const ENCOUNTERS := {
	&"hollow_forest": &"mawroot",
	&"forgotten_mine": &"forge_warden",
	&"blightheart_sanctum": &"blightheart",
}

func get_suite_name() -> String:
	return "boss_roster"

func run(t) -> void:
	var definitions := {}
	for boss_id: StringName in BOSSES:
		var definition := load("res://data/bosses/%s.tres" % boss_id) as BossDefinition
		t.assert_true(definition != null, "%s loads" % boss_id)
		if definition == null:
			continue
		definitions[boss_id] = definition
		var expected: Dictionary = BOSSES[boss_id]
		t.assert_eq(definition.id, boss_id, "%s keeps its id" % boss_id)
		t.assert_true(definition.is_boss, "%s is flagged as a boss" % boss_id)
		t.assert_eq(definition.recommended_level, expected["level"], "%s recommends its level" % boss_id)
		t.assert_true(definition.phases.size() >= expected["phases"], "%s runs enough phases" % boss_id)
		t.assert_true(definition.max_hp >= 2000.0, "%s is a damage sponge" % boss_id)
		t.assert_true(definition.xp >= 300.0, "%s pays a boss bounty" % boss_id)
		t.assert_eq(definition.contact_damage, 0.0, "%s only deals telegraphed damage" % boss_id)
		t.assert_true(definition.loot_table != null, "%s guards loot" % boss_id)
		t.assert_true(definition.display_scale > 1.0, "%s looms" % boss_id)
		_assert_attacks(t, definition)

	t.assert_true(definitions.size() == BOSSES.size(), "the roster authors every boss")
	_assert_escalation(t, definitions)
	_assert_mechanics(t, definitions)
	_assert_encounters(t)

	await _assert_barrage(t)
	await _assert_lunge_and_summon(t)
	await _assert_world_encounter(t)

	t.complete_suite(get_suite_name())

func _assert_attacks(t, definition: BossDefinition) -> void:
	var ids := {}
	for phase: BossPhaseDefinition in definition.phases:
		t.assert_true(phase.attacks.size() >= 2, "%s phase rotates real options" % definition.id)
		for attack: BossAttackDefinition in phase.attacks:
			t.assert_true(attack.windup_time >= 0.5, "%s telegraph respects reaction time" % definition.id)
			t.assert_true(attack.range > 0.0 and attack.width > 0.0, "%s telegraph has shape" % definition.id)
			ids[attack.id] = true
	t.assert_true(ids.size() >= 2, "%s fields distinct attacks" % definition.id)

func _assert_escalation(t, definitions: Dictionary) -> void:
	var boar := load("res://data/bosses/briarback_boar.tres") as BossDefinition
	if boar == null:
		t.assert_true(false, "the boar anchors the boss ladder")
		return
	t.assert_true(boar.recommended_level < definitions[&"mawroot"].recommended_level,
		"mawroot outranks the boar")
	t.assert_true(definitions[&"mawroot"].recommended_level < definitions[&"forge_warden"].recommended_level,
		"the warden outranks mawroot")
	t.assert_true(definitions[&"forge_warden"].recommended_level < definitions[&"blightheart"].recommended_level,
		"blightheart closes the continent")
	t.assert_true(definitions[&"blightheart"].max_hp > definitions[&"forge_warden"].max_hp,
		"the final boss outlasts the warden")

func _assert_mechanics(t, definitions: Dictionary) -> void:
	t.assert_true(_has_attack(definitions[&"mawroot"], func(attack: BossAttackDefinition) -> bool:
		return attack.repeat_count > 1), "mawroot introduces the multi-hit barrage")
	t.assert_true(_has_attack(definitions[&"forge_warden"], func(attack: BossAttackDefinition) -> bool:
		return attack.lunge_speed > 0.0), "the warden introduces the charge")
	t.assert_true(_has_attack(definitions[&"blightheart"], func(attack: BossAttackDefinition) -> bool:
		return attack.summon_count > 0 and attack.summon != null), "blightheart introduces summons")

func _has_attack(definition: BossDefinition, predicate: Callable) -> bool:
	for phase: BossPhaseDefinition in definition.phases:
		for attack: BossAttackDefinition in phase.attacks:
			if predicate.call(attack):
				return true
	return false

func _assert_encounters(t) -> void:
	for map_id: StringName in ENCOUNTERS:
		var definition := load("res://data/maps/%s.tres" % map_id) as MapDefinition
		t.assert_true(definition != null and definition.scene != null, "%s loads for its encounter" % map_id)
		if definition == null or definition.scene == null:
			continue
		var root: Node2D = definition.scene.instantiate()
		var encounters := root.find_children("*", "BossEncounter", true, false)
		t.assert_eq(encounters.size(), 1, "%s holds one boss encounter" % map_id)
		if encounters.size() == 1:
			var encounter := encounters[0] as BossEncounter
			t.assert_true(encounter.definition != null, "%s encounter names a boss" % map_id)
			if encounter.definition != null:
				t.assert_eq(encounter.definition.id, ENCOUNTERS[map_id], "%s encounter guards %s" % [map_id, ENCOUNTERS[map_id]])
		root.free()

func _assert_barrage(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	await t.physics_frame
	await t.physics_frame
	var player: Player = world.get_node("Player")
	player.apply_class(load("res://data/classes/mage.tres"))
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0
	player.hp = player.max_hp
	DebugManager.god_mode = true
	DebugManager.disable_ai = false

	var barrage := BossAttackDefinition.new()
	barrage.id = &"test_barrage"
	barrage.windup_time = 0.3
	barrage.active_time = 0.1
	barrage.recover_time = 0.2
	barrage.cooldown = 0.2
	barrage.damage = 3.0
	barrage.range = 200.0
	barrage.width = 200.0
	barrage.repeat_count = 3
	barrage.repeat_interval = 0.2

	var definition := BossDefinition.new()
	definition.id = &"test_barrage_boss"
	definition.max_hp = 100000.0
	definition.contact_damage = 0.0
	definition.xp = 0.0
	definition.is_boss = true
	var phase := BossPhaseDefinition.new()
	phase.threshold = 1.0
	phase.attacks = [barrage]
	definition.phases = [phase]

	var boss: Boss = load("res://scenes/bosses/boss.tscn").instantiate()
	boss.definition = definition
	player.global_position = Vector2(370.0, -60.0)
	boss.global_position = Vector2(290.0, -40.0)
	world.add_child(boss)
	await t.physics_frame
	player.global_position = Vector2(370.0, -60.0)
	var hits: Array = []
	boss.attack_resolved.connect(func(_id: StringName, count: int): hits.append(count))
	for _i in range(240):
		await t.physics_frame
		if not hits.is_empty():
			break
	t.assert_true(not hits.is_empty(), "the barrage resolves")
	if not hits.is_empty():
		t.assert_eq(hits[0], 3, "the barrage lands three hits")

	world.queue_free()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	await t.physics_frame

func _assert_lunge_and_summon(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	await t.physics_frame
	await t.physics_frame
	var player: Player = world.get_node("Player")
	player.apply_class(load("res://data/classes/mage.tres"))
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0
	player.hp = player.max_hp
	DebugManager.god_mode = true
	DebugManager.disable_ai = false

	var lunge := BossAttackDefinition.new()
	lunge.id = &"test_lunge"
	lunge.windup_time = 0.4
	lunge.active_time = 0.4
	lunge.recover_time = 0.2
	lunge.cooldown = 0.2
	lunge.damage = 3.0
	lunge.range = 200.0
	lunge.width = 160.0
	lunge.lunge_speed = 400.0

	var summon := BossAttackDefinition.new()
	summon.id = &"test_summon"
	summon.windup_time = 0.3
	summon.active_time = 0.1
	summon.recover_time = 0.2
	summon.cooldown = 0.2
	summon.damage = 0.0
	summon.range = 300.0
	summon.width = 200.0
	summon.summon = load("res://data/mobs/corrupted_slime.tres")
	summon.summon_count = 2

	var definition := BossDefinition.new()
	definition.id = &"test_mover_boss"
	definition.max_hp = 100000.0
	definition.contact_damage = 0.0
	definition.xp = 0.0
	definition.is_boss = true
	var phase := BossPhaseDefinition.new()
	phase.threshold = 1.0
	phase.attacks = [lunge, summon]
	definition.phases = [phase]

	var boss: Boss = load("res://scenes/bosses/boss.tscn").instantiate()
	boss.definition = definition
	boss.global_position = Vector2(200.0, -40.0)
	player.global_position = Vector2(280.0, -60.0)
	world.add_child(boss)
	await t.physics_frame
	player.global_position = Vector2(280.0, -60.0)

	var spawn_x := boss.global_position.x
	var max_offset := 0.0
	var resolved: Array = []
	boss.attack_resolved.connect(func(id: StringName, _count: int): resolved.append(id))
	for _i in range(600):
		await t.physics_frame
		max_offset = maxf(max_offset, absf(boss.global_position.x - spawn_x))
		if resolved.has(&"test_lunge") and resolved.has(&"test_summon"):
			break
	t.assert_true(resolved.has(&"test_lunge"), "the charge resolves")
	t.assert_true(max_offset > 40.0, "the charge moves the boss (%.1f px)" % max_offset)
	t.assert_true(resolved.has(&"test_summon"), "the summon resolves")
	var adds := 0
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and mob is Mob and not (mob is Boss) and (mob as Mob).mob_id() == &"corrupted_slime":
			adds += 1
	t.assert_true(adds >= 2, "the summon fields adds (%d)" % adds)

	world.queue_free()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	await t.physics_frame

func _assert_world_encounter(t) -> void:
	var game_scene: PackedScene = load("res://scenes/game/game.tscn")
	var game: Node2D = game_scene.instantiate()
	t.root.add_child(game)
	t.register_world(game)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame
	t.assert_true(WorldManager.travel_to(&"hollow_forest", &"default"), "the hollow forest loads")
	await t.physics_frame
	await t.physics_frame

	var player: Player = game.get_node("Player")
	var map_root: Node = game.get_node("World").get_child(0)
	var encounter := map_root.find_children("*", "BossEncounter", true, false)
	t.assert_eq(encounter.size(), 1, "the forest holds its encounter")
	if encounter.size() == 1:
		player.global_position = encounter[0].global_position
		for _i in range(20):
			await t.physics_frame
			if _boss_in_tree(t, &"mawroot"):
				break
	t.assert_true(_boss_in_tree(t, &"mawroot"), "entering the grove wakes mawroot")

	game.queue_free()
	await t.physics_frame
	await t.physics_frame

func _boss_in_tree(t, boss_id: StringName) -> bool:
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and mob is Boss and (mob as Boss).mob_id() == boss_id:
			return true
	return false
