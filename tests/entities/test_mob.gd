extends RefCounted

func get_suite_name() -> String:
	return "mob"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	await t.physics_frame
	var player: Player = world.get_node("Player")
	player.hp = player.max_hp

	for child: Node in world.get_children():
		if child.is_in_group("enemies"):
			child.queue_free()
	await t.physics_frame
	await t.physics_frame

	DebugManager.reset_counters()

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")
	t.assert_true(definition != null, "mob definition loads from data")
	t.assert_eq(definition.max_hp, 30.0, "definition carries normalized stats")

	var killed_events: Array = []
	EventBus.mob_died.connect(func(mob_id: StringName, xp: float, mob_definition: Resource):
		killed_events.append({"mob_id": mob_id, "xp": xp}))
	var applied_events: Array = []
	EventBus.damage_applied.connect(func(result: DamageResult):
		var hit_target = result.event.target
		applied_events.append({
			"result": result,
			"target_id": hit_target.get_instance_id() if is_instance_valid(hit_target) else -1,
		}))

	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame

	var mob: Mob = mob_scene.instantiate()
	mob.definition = definition
	mob.global_position = Vector2(180.0, -46.0)
	world.add_child(mob)
	var mob_instance_id := mob.get_instance_id()
	t.assert_true(mob.is_in_group("enemies"), "mob registers in the enemies group")
	t.assert_eq(mob.hp, definition.max_hp, "mob spawns at definition hp")

	var start_x := mob.global_position.x
	var approached := await _wait_until(t, func() -> bool:
		return mob.global_position.x - start_x > 30.0, 120)
	t.assert_true(approached, "mob approaches the player (moved %.1f px)" % (mob.global_position.x - start_x))

	var took_damage := await _wait_until(t, func() -> bool:
		return player.hp < player.max_hp, 240)
	t.assert_true(took_damage, "mob contact damages the player (hp=%s)" % player.hp)

	var hp_before_god := player.hp
	DebugManager.god_mode = true
	var hurt_in_god_mode := await _wait_until(t, func() -> bool:
		return player.hp < hp_before_god, 60)
	t.assert_false(hurt_in_god_mode, "god mode blocks contact damage (hp=%s)" % player.hp)
	DebugManager.god_mode = false
	player.heal_full()

	player.global_position = Vector2(300.0, -60.0)
	mob.global_position = Vector2(330.0, -46.0)
	await t.physics_frame
	await t.physics_frame

	var mob_hp_before := mob.hp
	Input.action_press("attack")
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	Input.action_release("attack")
	t.assert_true(mob.hp < mob_hp_before, "basic attack damages the mob (hp=%s)" % mob.hp)
	t.assert_eq(DebugManager.counters.kills, 0, "mob survives one hit")

	player.crit_chance = 1.0
	player.global_position = Vector2(300.0, -60.0)
	mob.global_position = Vector2(330.0, -46.0)
	await t.physics_frame
	await t.physics_frame
	for _i in range(25):
		await t.physics_frame
	Input.action_press("attack")
	await t.physics_frame
	await t.physics_frame
	await t.physics_frame
	Input.action_release("attack")
	player.crit_chance = 0.05
	var crit_hits := applied_events.filter(func(entry: Dictionary) -> bool:
		return int(entry.target_id) == mob_instance_id)
	t.assert_true(crit_hits.size() >= 1, "forced crit registers a damage event")
	if crit_hits.size() >= 1:
		var killing_blow: DamageResult = crit_hits.back().result
		t.assert_true(killing_blow.is_crit, "max crit chance produces a crit")
		t.assert_eq(killing_blow.applied, 24.0, "crit deals double damage through the pipeline")

	var attempts := 0
	while is_instance_valid(mob) and not mob.is_queued_for_deletion() and attempts < 12:
		attempts += 1
		Input.action_press("attack")
		for _i in range(25):
			await t.physics_frame
		Input.action_release("attack")
	await t.physics_frame
	t.assert_true(not is_instance_valid(mob) or mob.is_queued_for_deletion(), "dead mob despawns")
	t.assert_eq(killed_events.size(), 1, "mob death fires exactly one XP event (%d)" % killed_events.size())
	if killed_events.size() == 1:
		t.assert_eq(killed_events[0].mob_id, definition.id, "XP event carries mob id")
		t.assert_eq(killed_events[0].xp, definition.xp, "XP event carries xp value")
	t.assert_eq(DebugManager.counters.kills, 1, "kill counter incremented")

	var player_deaths: Array = []
	EventBus.player_died.connect(func(): player_deaths.append(1))
	player.hp = 10.0
	player.take_damage(50.0, null)
	t.assert_eq(player_deaths.size(), 1, "lethal hit emits player_died")
	t.assert_eq(player.hp, player.max_hp, "player respawns at full hp")
	t.assert_eq(player.global_position, Vector2(0.0, -60.0), "player respawns at spawn")

	var mob2: Mob = mob_scene.instantiate()
	mob2.definition = definition
	mob2.global_position = Vector2(600.0, -46.0)
	world.add_child(mob2)
	await t.physics_frame
	mob2.take_damage(999999.0, null)
	t.assert_true(mob2.is_queued_for_deletion(), "overkill kills the mob")
	mob2.take_damage(10.0, null)
	t.assert_eq(killed_events.size(), 2, "damage to dead mob fires no extra XP event")

	var killed := DebugManager.kill_all_enemies()
	t.assert_eq(killed, 0, "kill all skips already dead mobs")

	world.queue_free()
	await t.physics_frame
	Input.action_release("attack")
	t.complete_suite(get_suite_name())

func _wait_until(t, condition: Callable, max_frames: int) -> bool:
	for _i in range(max_frames):
		if condition.call():
			return true
		await t.physics_frame
	return condition.call()
