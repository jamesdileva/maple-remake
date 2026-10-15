extends RefCounted

const EXPECTED_DAMAGE := {
	&"boar_snort": 12.0,
	&"boar_stomp": 20.0,
	&"boar_shockwave": 16.0,
	&"boar_mire": 26.0,
}

func get_suite_name() -> String:
	return "first_boss"

func run(t) -> void:
	var definition := load("res://data/bosses/briarback_boar.tres") as BossDefinition
	t.assert_true(definition != null, "the boar definition loads from data")
	t.assert_eq(definition.id, &"briarback_boar", "the boar declares its id")
	t.assert_eq(definition.max_hp, 3000.0, "the boar is a real damage sponge")
	t.assert_eq(definition.phases.size(), 2, "the boar fights in two phases")
	t.assert_eq(definition.contact_damage, 0.0, "all boar damage is telegraphed")
	for phase: BossPhaseDefinition in definition.phases:
		t.assert_true(phase.attacks.size() >= 3, "every phase rotates real options")
		for attack: BossAttackDefinition in phase.attacks:
			t.assert_true(attack.windup_time >= 0.5, "every telegraph respects reaction time")

	var game_scene: PackedScene = load("res://scenes/game/game.tscn")
	var game: Node2D = game_scene.instantiate()
	t.root.add_child(game)
	t.register_world(game)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame
	t.assert_true(WorldManager.travel_to(&"thornhollow_ring", &"default"), "the arena loads")
	await t.physics_frame
	await t.physics_frame

	var player: Player = game.get_node("Player")
	var arena: Node = game.get_node("World").get_child(0)
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	player.apply_class(mage)
	player.set_level(10)
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0
	DebugManager.god_mode = false
	DebugManager.disable_ai = false

	var boss_scene: PackedScene = load("res://scenes/bosses/boss.tscn")
	var boss: Boss = boss_scene.instantiate()
	boss.definition = definition
	player.global_position = Vector2(100.0, -60.0)
	player.hp = player.max_hp
	boss.global_position = Vector2(0.0, -40.0)
	arena.add_child(boss)
	var feed := {"pending_hp": 0.0, "started": [], "damages": {}}
	boss.attack_started.connect(func(attack_id: StringName):
		feed.started.append(attack_id)
		feed.pending_hp = player.hp)
	boss.attack_resolved.connect(func(attack_id: StringName, _hits: int):
		if not feed.damages.has(attack_id):
			feed.damages[attack_id] = []
		feed.damages[attack_id].append(feed.pending_hp - player.hp))
	await t.physics_frame
	await t.physics_frame
	t.assert_true(boss.is_in_group("enemies"), "the boar counts as an enemy")
	t.assert_almost_eq(boss.scale.x, 1.5, 0.01, "the boar looms over slimes")
	t.assert_eq(boss.get_node("Visual").modulate, Color(1.0, 0.45, 0.4, 1.0), "the boar wears its tint")
	t.assert_eq(boss.hp, 3000.0, "the boar enters at full hp")

	for _i in range(1100):
		await t.physics_frame
		if feed.started.size() >= 6:
			break
	t.assert_eq(feed.started.slice(0, 3), [&"boar_snort", &"boar_stomp", &"boar_shockwave"],
		"the opening rotation is fixed")
	t.assert_eq(feed.started.slice(3, 6), [&"boar_snort", &"boar_stomp", &"boar_shockwave"],
		"the rotation repeats identically")
	for attack_id: StringName in EXPECTED_DAMAGE:
		if attack_id == &"boar_mire":
			continue
		t.assert_true(feed.damages.has(attack_id), "the %s lands" % String(attack_id))
		t.assert_almost_eq(feed.damages[attack_id][0], EXPECTED_DAMAGE[attack_id], 0.5,
			"the %s deals its data damage" % String(attack_id))
	t.assert_true(player.max_hp * 0.5 > EXPECTED_DAMAGE[&"boar_mire"], "no single hit halves the expected hero")

	player.hp = player.max_hp
	player.global_position = Vector2(-550.0, -60.0)
	var safe_hits: int = feed.started.size()
	for _i in range(600):
		await t.physics_frame
		if feed.started.size() >= safe_hits + 3:
			break
	t.assert_true(feed.started.size() >= safe_hits + 3, "the boar keeps swinging at the far edge")
	t.assert_eq(player.hp, player.max_hp, "the far edge is a true safe spot")

	for _i in range(120):
		await t.physics_frame
		if boss.state_name() == &"idle":
			break
	player.hp = player.max_hp
	boss.take_damage(1600.0, player)
	await t.physics_frame
	t.assert_eq(boss.phase_index, 1, "bloodied hide enrages the boar")
	var enraged_from: int = feed.started.size()
	player.global_position = Vector2(100.0, -60.0)
	for _i in range(900):
		await t.physics_frame
		if feed.started.size() >= enraged_from + 4:
			break
	t.assert_eq(feed.started.slice(enraged_from, enraged_from + 4),
		[&"boar_shockwave", &"boar_mire", &"boar_stomp", &"boar_snort"],
		"the enraged rotation adds the mire stomp")
	t.assert_true(feed.damages.has(&"boar_mire"), "the mire stomp lands")
	t.assert_almost_eq(feed.damages[&"boar_mire"][0], 26.0, 0.5, "the mire stomp deals its data damage")

	var fma_before: float = boss.hp
	for _i in range(6):
		player.mana = player.max_mana
		Input.action_press("skill_4")
		for _j in range(3):
			await t.physics_frame
		Input.action_release("skill_4")
		for _j in range(150):
			if not player.is_casting():
				break
			await t.physics_frame
	t.assert_almost_eq(fma_before - boss.hp, 360.0, 1.0, "base-kit storms chew through the hide")

	LootManager.enabled = true
	var xp_before: float = player.xp
	var hoard: Array = []
	EventBus.mob_died.connect(func(mob_id: StringName, _xp: float, _definition: Resource):
		if mob_id == &"briarback_boar":
			hoard.append(mob_id))
	boss.take_damage(999999.0, player)
	t.assert_true(boss.is_dead(), "the boar can be slain")
	t.assert_true(boss.is_queued_for_deletion(), "the slain boar leaves the ring")
	t.assert_eq(hoard, [&"briarback_boar"], "the kill travels the shared pipeline")
	t.assert_true(LootManager.stats()["spawned"] > 0, "the hoard drops real loot")
	t.assert_true(player.xp >= xp_before + 250.0, "the hoard includes a hero's xp")
	await t.physics_frame
	await t.physics_frame

	game.queue_free()
	await t.physics_frame
	await t.physics_frame

	var lab_scene: PackedScene = load("res://scenes/lab/combat_lab.tscn")
	var lab_root: Node2D = lab_scene.instantiate()
	t.root.add_child(lab_root)
	t.register_world(lab_root)
	await t.physics_frame
	await t.physics_frame
	var lab: CombatLab = lab_root.get_node("Lab")
	var boss_option: OptionButton = lab.get_node("LabUI/Panel/VBox/BossOption")
	boss_option.select(2)
	DebugManager.god_mode = true
	t.assert_eq(lab.spawn(), 1, "the lab spawns the boar")
	var lab_boar: Boss = null
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and mob is Boss and (mob as Boss).mob_id() == &"briarback_boar":
			lab_boar = mob
	t.assert_true(lab_boar != null, "the lab fields a real boss entity")

	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	SpawnManager.enabled = false
	LootManager.enabled = false
	lab_root.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
