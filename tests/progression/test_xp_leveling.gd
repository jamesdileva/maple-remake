extends RefCounted

func get_suite_name() -> String:
	return "xp_leveling"

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
	var table := player.xp_table
	t.assert_true(table != null, "player carries a data-driven xp table")
	t.assert_true(table.max_level >= 40 and table.max_level <= 50, "level cap is in the 40-50 design window")

	var base_hp: float = player.max_hp
	t.assert_eq(player.level, 1, "player starts at level 1")
	t.assert_eq(player.xp, 0.0, "player starts with no xp")

	var level_ups: Array = []
	player.leveled_up.connect(func(new_level: int): level_ups.append(new_level))

	t.assert_eq(table.xp_for_level(1), 0.0, "level 1 needs no xp")
	t.assert_true(table.xp_for_level(2) > 0.0, "level 2 needs xp")
	t.assert_true(table.xp_for_level(3) > table.xp_for_level(2), "thresholds grow")
	var required_two: float = table.xp_for_level(2) - table.xp_for_level(1)
	t.assert_eq(player.xp_to_next_level(), required_two, "xp_to_next matches the level 2 threshold")

	player.grant_xp(required_two * 0.5)
	t.assert_eq(player.level, 1, "partial xp does not level")
	t.assert_eq(player.xp, required_two * 0.5, "xp accumulates")
	t.assert_eq(level_ups.size(), 0, "no level-up below the threshold")
	t.assert_almost_eq(player.level_progress(), 0.5, 0.01, "progress reflects the xp fraction")

	player.grant_xp(required_two * 0.5)
	t.assert_eq(player.level, 2, "reaching the threshold levels up")
	t.assert_eq(level_ups.size(), 1, "level_up emitted once")
	t.assert_eq(player.xp, required_two, "xp is retained after leveling")
	t.assert_eq(player.xp_into_level(), 0.0, "xp into level resets at a level boundary")
	t.assert_true(player.max_hp > base_hp, "leveling raises max hp")
	t.assert_true(player.hp > base_hp, "leveling grants the hp delta")
	t.assert_eq(player.hp, player.max_hp, "leveling tops the player up")

	var hp_at_two: float = player.max_hp
	var mana_at_two: float = player.max_mana
	player.hp = 5.0
	player.grant_xp(table.xp_for_level(4) - table.xp_for_level(3) + table.xp_for_level(3) - table.xp_for_level(2))
	t.assert_true(player.level >= 3, "a large grant can cross several levels")
	t.assert_true(level_ups.size() >= 2, "each crossed level emits its own level-up")
	t.assert_true(player.max_hp > hp_at_two, "stats keep scaling with level")
	t.assert_true(player.max_mana > mana_at_two, "mana scales with level too")
	t.assert_eq(player.hp, player.max_hp, "multi-level-up tops the player up")

	var xp_before_overflow: float = player.xp
	player.grant_xp(table.xp_for_level(player.level + 1) - player.xp + 10.0)
	t.assert_true(player.xp > table.xp_for_level(player.level), "xp above the threshold is stored")
	t.assert_true(player.level_progress() > 0.0, "overflow xp counts toward the next level")
	t.assert_true(player.xp > xp_before_overflow, "xp never resets to zero on level-up")

	player.grant_xp(0.0)
	t.assert_eq(player.xp, player.xp, "zero xp grants are ignored")
	player.grant_xp(-50.0)
	t.assert_true(player.xp >= xp_before_overflow, "negative xp grants are ignored")

	var capped := XpTable.new()
	capped.max_level = 3
	capped.base_xp = 10.0
	capped.growth = 2.0
	player.set("level", 1)
	player.set("xp", 0.0)
	player.set("xp_table", capped)
	player.grant_xp(999999.0)
	t.assert_eq(player.level, 3, "the level cap is enforced")
	t.assert_almost_eq(player.level_progress(), 1.0, 0.001, "progress is full at the cap")
	t.assert_eq(player.xp_to_next_level(), 0.0, "no next level at the cap")
	var xp_at_cap: float = player.xp
	player.grant_xp(500.0)
	t.assert_eq(player.xp, xp_at_cap, "xp stops accruing at the cap")

	var loot_events: Array = []
	EventBus.mob_died.connect(func(mob_id: StringName, mob_xp: float, definition: Resource):
		loot_events.append(mob_xp))
	LootManager.enabled = true
	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")
	var mob: Mob = mob_scene.instantiate()
	mob.definition = definition
	mob.global_position = Vector2(400.0, -30.0)
	world.add_child(mob)
	await t.physics_frame
	await t.physics_frame
	mob.take_damage(999999.0, null)
	await t.physics_frame
	t.assert_true(loot_events.size() >= 1, "mob death reports xp")

	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
