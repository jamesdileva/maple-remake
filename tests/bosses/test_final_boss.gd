extends RefCounted

const BOSS_ID := &"blightheart"
const SANCTUM := &"blightheart_sanctum"
const OTHER_BOSSES := [&"briarback_boar", &"mawroot", &"forge_warden"]

func get_suite_name() -> String:
	return "final_boss"

func run(t) -> void:
	var definition := load("res://data/bosses/blightheart.tres") as BossDefinition
	t.assert_true(definition != null, "the final boss loads from data")
	if definition == null:
		t.complete_suite(get_suite_name())
		return

	t.assert_eq(definition.id, BOSS_ID, "the final boss declares its id")
	t.assert_true(definition.is_boss, "the final boss is a boss")
	t.assert_true(definition.is_final, "the final boss closes the continent")
	t.assert_eq(definition.recommended_level, 28, "the final boss expects level 28")
	t.assert_true(definition.max_hp >= 7000.0, "the final boss is the longest fight")
	t.assert_eq(definition.phases.size(), 3, "the final boss fights in three phases")
	t.assert_true(definition.contact_damage == 0.0, "every final blow is telegraphed")

	for other_id: StringName in OTHER_BOSSES:
		var other := load("res://data/bosses/%s.tres" % other_id) as BossDefinition
		t.assert_true(other != null and not other.is_final,
			"%s is not the final boss" % other_id)
		if other != null:
			t.assert_true(definition.max_hp > other.max_hp,
				"the final boss outlasts %s" % other_id)

	var thresholds: Array[float] = []
	for phase: BossPhaseDefinition in definition.phases:
		thresholds.append(phase.threshold)
		t.assert_true(phase.attacks.size() >= 2, "every phase rotates real options")
		for attack: BossAttackDefinition in phase.attacks:
			t.assert_true(attack.windup_time >= 0.6,
				"%s telegraphs for a readable beat" % attack.id)
			t.assert_true(attack.active_time <= attack.windup_time,
				"%s strikes no faster than it warns" % attack.id)
			t.assert_true(attack.damage > 0.0, "%s deals real damage" % attack.id)
			t.assert_true(attack.telegraph_color.a >= 0.5,
				"%s warns in visible color" % attack.id)
	t.assert_almost_eq(thresholds[0], 1.0, 0.001, "phase one starts at full hp")
	t.assert_true(thresholds[1] < thresholds[0] and thresholds[2] < thresholds[1],
		"phase thresholds descend")
	t.assert_true(definition.phases[1].attacks.size() >= definition.phases[0].attacks.size(),
		"phase two adds pressure")
	t.assert_true(_has_summon(definition), "the final boss calls adds")
	t.assert_true(_has_attack(definition, &"blight_wave"), "the last phase adds the wave")

	var hoard_ids := {}
	for entry in definition.loot_table.entries:
		if entry != null and entry.item != null:
			hoard_ids[entry.item.id] = true
	t.assert_true(hoard_ids.has(&"sanctum_blade") and hoard_ids.has(&"sanctum_staff"),
		"the final hoard carries sanctum weapons")
	t.assert_true(hoard_ids.has(&"blight_helm"), "the final hoard carries its helm")
	t.assert_true(definition.xp >= 1200.0, "the final kill pays a hero's xp")

	var sanctum: PackedScene = load("res://scenes/maps/blightheart_sanctum.tscn")
	var map: Node2D = sanctum.instantiate()
	var encounters := map.find_children("*", "BossEncounter", true, false)
	t.assert_eq(encounters.size(), 1, "the sanctum guards one encounter")
	if encounters.size() == 1:
		var encounter := encounters[0] as BossEncounter
		t.assert_true(encounter.definition != null and encounter.definition.id == BOSS_ID,
			"the sanctum encounter is the final boss")
	map.free()

	await _fight(t, definition)

	t.complete_suite(get_suite_name())

func _has_summon(definition: BossDefinition) -> bool:
	for phase: BossPhaseDefinition in definition.phases:
		for attack: BossAttackDefinition in phase.attacks:
			if attack.summon_count > 0 and attack.summon != null:
				return true
	return false

func _has_attack(definition: BossDefinition, attack_id: StringName) -> bool:
	for phase: BossPhaseDefinition in definition.phases:
		for attack: BossAttackDefinition in phase.attacks:
			if attack.id == attack_id:
				return true
	return false

func _fight(t, definition: BossDefinition) -> void:
	var game_scene: PackedScene = load("res://scenes/game/game.tscn")
	var game: Node2D = game_scene.instantiate()
	t.root.add_child(game)
	t.register_world(game)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame
	t.assert_true(WorldManager.travel_to(SANCTUM, &"default"), "the sanctum loads")
	await t.physics_frame
	await t.physics_frame

	var player: Player = game.get_node("Player")
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	player.apply_class(mage)
	player.set_level(definition.recommended_level)
	player.crit_chance = 0.0
	DebugManager.god_mode = false
	DebugManager.disable_ai = true

	var boss: Boss = (load("res://scenes/bosses/boss.tscn") as PackedScene).instantiate()
	boss.definition = definition
	boss.global_position = Vector2(0.0, -40.0)
	game.get_node("World").get_child(0).add_child(boss)
	var phases: Array = []
	var finals: Array = []
	boss.phase_changed.connect(func(index: int): phases.append(index))
	EventBus.final_boss_defeated.connect(func(boss_id: StringName): finals.append(boss_id))
	await t.physics_frame
	await t.physics_frame
	t.assert_eq(boss.hp, definition.max_hp, "the final boss enters at full health")

	boss.take_damage(definition.max_hp * 0.35, player)
	await t.physics_frame
	t.assert_eq(boss.phase_index, 1, "the second phase opens at two thirds")
	boss.take_damage(definition.max_hp * 0.34, player)
	await t.physics_frame
	t.assert_eq(boss.phase_index, 2, "the last phase opens at one third")
	t.assert_eq(phases, [1, 2], "every threshold announces itself once")

	var xp_before: float = player.xp
	LootManager.enabled = true
	boss.take_damage(999999.0, player)
	t.assert_true(boss.is_dead(), "the final boss can be slain")
	t.assert_eq(finals, [BOSS_ID], "the kill raises the final banner")
	t.assert_true(player.xp >= xp_before + definition.xp, "the final kill pays its xp")
	t.assert_true(LootManager.stats()["spawned"] > 0, "the final hoard hits the ground")
	await t.physics_frame
	await t.physics_frame

	LootManager.enabled = false
	game.queue_free()
	await t.physics_frame
	await t.physics_frame
