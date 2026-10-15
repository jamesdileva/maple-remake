extends RefCounted

func get_suite_name() -> String:
	return "boss_framework"

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
	var warrior: ClassDefinition = load("res://data/classes/warrior.tres")
	player.apply_class(mage)
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0

	DebugManager.god_mode = false
	DebugManager.disable_ai = true

	var swipe := BossAttackDefinition.new()
	swipe.id = &"test_swipe"
	swipe.display_name = "Test Swipe"
	swipe.windup_time = 0.3
	swipe.active_time = 0.1
	swipe.recover_time = 0.2
	swipe.cooldown = 0.2
	swipe.damage = 15.0
	swipe.range = 120.0
	swipe.width = 160.0
	swipe.area_mode = BossAttackDefinition.Area.FRONTAL
	swipe.telegraph_color = Color(1.0, 0.25, 0.2, 1.0)

	var slam := BossAttackDefinition.new()
	slam.id = &"test_slam"
	slam.display_name = "Test Slam"
	slam.windup_time = 0.4
	slam.active_time = 0.1
	slam.recover_time = 0.3
	slam.damage = 25.0
	slam.range = 200.0
	slam.width = 200.0
	slam.area_mode = BossAttackDefinition.Area.CENTERED
	slam.telegraph_color = Color(0.7, 0.2, 0.9, 1.0)

	var first := BossPhaseDefinition.new()
	first.threshold = 1.0
	first.attacks = [swipe]
	var second := BossPhaseDefinition.new()
	second.threshold = 0.5
	second.attacks = [slam, swipe]

	var definition := BossDefinition.new()
	definition.id = &"test_boss"
	definition.display_name = "Test Boss"
	definition.max_hp = 200.0
	definition.move_speed = 0.0
	definition.contact_damage = 0.0
	definition.xp = 10.0
	definition.gravity = 900.0
	definition.defense = 0.0
	definition.is_boss = true
	definition.phases = [first, second]

	var boss_scene: PackedScene = load("res://scenes/bosses/boss.tscn")
	var boss: Boss = boss_scene.instantiate()
	boss.definition = definition
	boss.global_position = Vector2(370.0, -40.0)
	world.add_child(boss)
	await t.physics_frame
	await t.physics_frame

	t.assert_true(boss.is_in_group("enemies"), "the boss counts as an enemy")
	t.assert_eq(boss.state_name(), &"idle", "the boss idles with disabled AI")
	t.assert_eq(boss.phase_index, 0, "the boss starts in phase one")
	for _i in range(60):
		await t.physics_frame
	t.assert_eq(boss.state_name(), &"idle", "disabled AI never telegraphs")
	t.assert_eq(_telegraphs(t).size(), 0, "disabled AI draws no telegraphs")

	var started: Array = []
	boss.attack_started.connect(func(attack_id: StringName): started.append(attack_id))
	var resolved: Array = []
	boss.attack_resolved.connect(func(attack_id: StringName, hits: int): resolved.append([attack_id, hits]))
	var phases: Array = []
	boss.phase_changed.connect(func(phase_index: int): phases.append(phase_index))

	player.global_position = Vector2(300.0, -60.0)
	player.hp = player.max_hp
	DebugManager.disable_ai = false
	await t.physics_frame
	await t.physics_frame

	for _i in range(120):
		await t.physics_frame
		if not started.is_empty():
			break
	t.assert_eq(started, [&"test_swipe"], "the first strike announces itself")
	t.assert_eq(boss.state_name(), &"windup", "the telegraph holds the boss in windup")
	var telegraphs := _telegraphs(t)
	t.assert_eq(telegraphs.size(), 1, "exactly one telegraph marks the strike")
	var telegraph: CastTelegraph = telegraphs[0]
	t.assert_almost_eq(telegraph.scale.x, 120.0 / 52.0, 0.4, "the telegraph spans the attack range")
	t.assert_almost_eq(telegraph.scale.y, 160.0 / 24.0, 0.9, "the telegraph spans the attack width")
	t.assert_eq(telegraph.modulate, Color(1.0, 0.25, 0.2, 1.0), "the telegraph uses the data color")
	t.assert_eq(player.hp, player.max_hp, "the windup deals no damage yet")

	var hp_before: float = player.hp
	for _i in range(120):
		await t.physics_frame
		if boss.state_name() == &"recover":
			break
	t.assert_eq(boss.state_name(), &"recover", "the strike lands in a recovery window")
	t.assert_almost_eq(hp_before - player.hp, 15.0, 0.5, "the swipe deals its data damage")
	t.assert_eq(started, [&"test_swipe"], "the strike announces itself")
	t.assert_eq(resolved.size(), 1, "the strike resolves exactly once")

	player.global_position = Vector2(0.0, -60.0)
	for _i in range(200):
		await t.physics_frame
		if resolved.size() >= 2:
			break
	t.assert_true(resolved.size() >= 2, "the boss keeps attacking on its own")
	t.assert_eq(player.hp, hp_before - 15.0, "the safe spot takes no damage")

	for _i in range(120):
		await t.physics_frame
		if boss.state_name() == &"idle":
			break
	boss.take_damage(120.0, player)
	await t.physics_frame
	t.assert_eq(boss.hp, 80.0, "the boss tracks damage through the pipeline")
	t.assert_eq(boss.phase_index, 1, "halved hp advances the phase")
	t.assert_eq(phases, [1], "the phase change announces itself")
	t.assert_eq(boss.current_attack().id, &"test_slam", "the new phase brings new attacks")
	t.assert_eq(_telegraphs(t).size(), 0, "phasing cancels any live telegraph")

	var seen := []
	for _i in range(200):
		seen.append(boss.state_name())
		await t.physics_frame
		if seen.has(&"recover") and boss.state_name() == &"idle":
			break
	for expected: StringName in [&"idle", &"windup", &"active", &"recover"]:
		t.assert_true(seen.has(expected), "the cycle passes through %s" % String(expected))

	player.apply_class(warrior)
	boss.take_damage(30.0, player)
	boss.global_position += Vector2(100.0, 0.0)
	await t.physics_frame
	boss.reset()
	t.assert_eq(boss.hp, 200.0, "reset restores full hp")
	t.assert_eq(boss.phase_index, 0, "reset restores the first phase")
	t.assert_eq(boss.state_name(), &"idle", "reset restores the idle state")
	t.assert_almost_eq(boss.global_position.x, 370.0, 1.0, "reset restores the arena position")

	boss.take_damage(50.0, player)
	t.assert_true(boss.hp < 200.0, "the boss is softened before the retry check")
	player.hp = 10.0
	player.take_damage(999999.0, null)
	await t.physics_frame
	await t.physics_frame
	t.assert_eq(boss.hp, 200.0, "a dead player means a fresh boss")
	t.assert_eq(boss.phase_index, 0, "a dead player means the first phase")

	var boss_xp_before: float = player.xp
	var boss_deaths: Array = []
	EventBus.mob_died.connect(func(mob_id: StringName, _xp: float, _definition: Resource):
		if mob_id == &"test_boss":
			boss_deaths.append(mob_id))
	boss.take_damage(999999.0, player)
	t.assert_true(boss.is_dead(), "overwhelming damage kills the boss")
	t.assert_true(boss.is_queued_for_deletion(), "the dead boss leaves the arena")
	t.assert_eq(boss_deaths, [&"test_boss"], "boss death travels the shared kill pipeline")
	t.assert_true(player.xp >= boss_xp_before + 10.0, "boss xp reaches the player")
	await t.physics_frame
	await t.physics_frame

	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _telegraphs(t) -> Array:
	var found := []
	for node in t.get_nodes_in_group("effects"):
		if is_instance_valid(node) and node is CastTelegraph:
			found.append(node)
	return found
