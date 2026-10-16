extends RefCounted

const BOSS_PATH := "res://data/bosses/briarback_boar.tres"
const BOSS_SCENE := "res://scenes/bosses/boss.tscn"
const CLASS_PATH := "res://data/classes/mage.tres"
const FMA_ACTION := "skill_4"
const EXPECTED_LEVEL := 12

const MAX_FRAMES := 9000
const PROBE_FRAMES := 1200

func get_suite_name() -> String:
	return "boss_balance"

func run(t) -> void:
	var definition := load(BOSS_PATH) as BossDefinition
	t.assert_true(definition != null, "the first boss loads")
	t.assert_true(definition.recommended_level > 1, "the boar declares an expected level")
	t.assert_eq(definition.recommended_level, EXPECTED_LEVEL, "the first boss expects level 12")
	var slime: MobDefinition = load("res://data/mobs/test_slime.tres")
	t.assert_eq(slime.recommended_level, 1, "ordinary mobs carry no level gate")

	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame
	var player: Player = world.get_node("Player")
	await _clear_enemies(t)

	var under := maxi(1, definition.recommended_level / 2)
	var bands := {
		&"underleveled": {"level": under, "advance": false, "fma_level": 1},
		&"expected": {"level": definition.recommended_level, "advance": false, "fma_level": 5},
		&"overleveled": {"level": 40, "advance": true, "fma_level": 5},
	}

	DebugManager.god_mode = true
	DebugManager.disable_ai = false
	var races := {}
	var hero_hp := {}
	for band: StringName in bands:
		_configure_player(player, bands[band])
		hero_hp[band] = player.max_hp
		races[band] = await _run_fight(t, player, world, definition)
		print("boss_balance: %s (lv %d) killed in %d casts / %d frames, %d telegraphs, phase2=%s" % [
			String(band), int(bands[band].level), races[band].casts, races[band].frames,
			races[band].telegraphs, str(races[band].phase_two)])

	for band: StringName in races:
		t.assert_true(races[band].killed, "the %s hero can still destroy the boar" % String(band))
		t.assert_true(races[band].telegraphs >= 3,
			"the boar still telegraphs against the %s hero (%d)" % [String(band), races[band].telegraphs])
		t.assert_true(races[band].phase_two,
			"the boar still enrages against the %s hero" % String(band))
	t.assert_true(races[&"expected"].frames < races[&"underleveled"].frames,
		"a leveled hero shortens the fight (%d < %d)" % [races[&"expected"].frames, races[&"underleveled"].frames])
	t.assert_true(races[&"overleveled"].frames < races[&"expected"].frames,
		"an overpowered hero destroys the boar (%d < %d)" % [races[&"overleveled"].frames, races[&"expected"].frames])
	t.assert_true(races[&"overleveled"].frames * 2 <= races[&"underleveled"].frames,
		"overleveling more than halves the fight (%d vs %d)" % [races[&"overleveled"].frames, races[&"underleveled"].frames])

	DebugManager.god_mode = false

	_configure_player(player, bands[&"expected"])
	var safe := await _run_probe(t, player, world, definition, Vector2(-550.0, -60.0), 3)
	t.assert_true(safe.resolved >= 3, "the boar keeps swinging while the hero camps the far edge")
	t.assert_eq(safe.total, 0.0, "the far edge is a true safe zone at the expected level")

	var front := await _run_probe(t, player, world, definition, Vector2(100.0, -60.0), 3)
	var rotation := 0.0
	for attack_id: StringName in front.damages:
		rotation += front.damages[attack_id][0]
	for attack_id: StringName in [&"boar_snort", &"boar_stomp", &"boar_shockwave"]:
		t.assert_true(front.damages.has(attack_id),
			"the %s still lands at the expected level" % String(attack_id))
	t.assert_almost_eq(front.damages[&"boar_snort"][0], 12.0, 0.5, "the snort reads for 12")
	t.assert_almost_eq(front.damages[&"boar_stomp"][0], 20.0, 0.5, "the stomp reads for 20")
	t.assert_almost_eq(front.damages[&"boar_shockwave"][0], 16.0, 0.5, "the shockwave reads for 16")

	_configure_player(player, bands[&"underleveled"])
	var weak := await _run_probe(t, player, world, definition, Vector2(100.0, -60.0), 1)
	t.assert_true(weak.resolved >= 1, "the boar still telegraphs against an underleveled hero")
	t.assert_almost_eq(weak.damages[&"boar_snort"][0], 12.0, 0.5,
		"the opening telegraph reads identically when underleveled")
	t.assert_true(rotation < hero_hp[&"underleveled"],
		"a full opening rotation never one-shots an underleveled hero (%.0f < %.0f)" % [rotation, hero_hp[&"underleveled"]])
	var under_share: float = rotation / float(hero_hp[&"underleveled"])
	var over_share: float = rotation / float(hero_hp[&"overleveled"])
	t.assert_true(under_share > over_share * 2.0,
		"level meaningfully reduces incoming pressure (%.2f vs %.2f)" % [under_share, over_share])

	var snapshot_path: String = DebugManager.export_debug_data()
	t.assert_true(FileAccess.get_file_as_string(snapshot_path).contains("\"bosses\""),
		"boss balance telemetry reaches the debug snapshot")

	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _configure_player(player: Player, band: Dictionary) -> void:
	player.apply_class(load(CLASS_PATH) as ClassDefinition)
	player.set_level(int(band["level"]))
	if bool(band["advance"]):
		player.advance()
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0
	var fma_id := "mage_fma_2" if bool(band["advance"]) else "mage_fma"
	var fma: AbilityDefinition = load("res://data/abilities/%s.tres" % fma_id)
	for _i in range(int(band["fma_level"]) - 1):
		player.spend_skill_point(fma)
	player.hp = player.max_hp
	player.mana = player.max_mana

func _run_fight(t, player: Player, world: Node2D, definition: BossDefinition) -> Dictionary:
	var boss: Boss = (load(BOSS_SCENE) as PackedScene).instantiate()
	boss.definition = definition
	player.global_position = Vector2(100.0, -60.0)
	player.hp = player.max_hp
	player.mana = player.max_mana
	boss.global_position = Vector2(0.0, -40.0)
	world.add_child(boss)
	var feed := {"started": 0, "phase_two": false, "killed": false}
	boss.attack_started.connect(func(_attack_id: StringName): feed.started += 1)
	boss.phase_changed.connect(func(index: int): feed.phase_two = index > 0)
	var on_died := func(mob_id: StringName, _xp: float, _resource: Resource) -> void:
		if mob_id == definition.id:
			feed.killed = true
	EventBus.mob_died.connect(on_died)
	await t.physics_frame
	await t.physics_frame
	var casts := 0
	var frames := 0
	while frames < MAX_FRAMES and is_instance_valid(boss) and not boss.is_dead():
		if not player.is_casting():
			player.mana = player.max_mana
			Input.action_press(FMA_ACTION)
			for _i in range(3):
				frames += 1
				await t.physics_frame
			Input.action_release(FMA_ACTION)
			if player.is_casting():
				casts += 1
			for _i in range(600):
				frames += 1
				await t.physics_frame
				if not player.is_casting():
					break
			continue
		frames += 1
		await t.physics_frame
	EventBus.mob_died.disconnect(on_died)
	if is_instance_valid(boss):
		feed.killed = feed.killed or boss.is_dead()
		boss.queue_free()
	await t.physics_frame
	await t.physics_frame
	return {
		"killed": feed.killed,
		"casts": casts,
		"frames": frames,
		"telegraphs": feed.started,
		"phase_two": feed.phase_two,
	}

func _run_probe(t, player: Player, world: Node2D, definition: BossDefinition,
		position: Vector2, wanted: int) -> Dictionary:
	var boss: Boss = (load(BOSS_SCENE) as PackedScene).instantiate()
	boss.definition = definition
	player.global_position = position
	player.hp = player.max_hp
	player.mana = player.max_mana
	boss.global_position = Vector2(0.0, -40.0)
	world.add_child(boss)
	var feed := {"pending": player.hp, "damages": {}, "total": 0.0, "resolved": 0, "hits": 0}
	boss.attack_started.connect(func(_attack_id: StringName): feed.pending = player.hp)
	boss.attack_resolved.connect(func(attack_id: StringName, hits: int):
		feed.resolved += 1
		if hits <= 0:
			return
		var delta: float = feed.pending - player.hp
		if not feed.damages.has(attack_id):
			feed.damages[attack_id] = []
		feed.damages[attack_id].append(delta)
		feed.total += delta
		feed.hits += 1)
	await t.physics_frame
	await t.physics_frame
	for _i in range(PROBE_FRAMES):
		if feed.resolved >= wanted or not is_instance_valid(boss) or boss.is_dead():
			break
		await t.physics_frame
	if is_instance_valid(boss):
		boss.queue_free()
	await t.physics_frame
	await t.physics_frame
	return feed

func _clear_enemies(t) -> void:
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob):
			mob.queue_free()
	await t.physics_frame
	await t.physics_frame
