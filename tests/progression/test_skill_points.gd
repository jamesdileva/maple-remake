extends RefCounted

func get_suite_name() -> String:
	return "skill_points"

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
	var burst: AbilityDefinition = load("res://data/abilities/arcane_burst.tres")
	var storm: AbilityDefinition = load("res://data/abilities/arc_storm.tres")
	t.assert_true(burst.max_level >= 2, "abilities carry a max level")
	t.assert_true(burst.damage_per_level > 0.0, "abilities scale damage per level")
	t.assert_true(storm.unlock_level >= 1, "abilities carry an unlock level")

	t.assert_eq(player.skill_points, 0, "fresh characters hold no skill points")
	t.assert_eq(player.ability_level(burst), 1, "abilities start at level 1")
	t.assert_false(player.spend_skill_point(burst), "spending with no points fails")
	t.assert_eq(player.ability_level(burst), 1, "failed spend changes nothing")

	player.add_skill_points(3)
	t.assert_eq(player.skill_points, 3, "points accrue")
	t.assert_true(player.spend_skill_point(burst), "a valid spend succeeds")
	t.assert_eq(player.skill_points, 2, "spending consumes exactly one point")
	t.assert_eq(player.skill_points_spent, 1, "spent points are tracked")
	t.assert_eq(player.ability_level(burst), 2, "the ability reaches level 2")

	t.assert_eq(burst.damage_at(1), burst.damage, "level 1 uses base damage")
	t.assert_eq(burst.damage_at(2), burst.damage + burst.damage_per_level, "level 2 adds one scaling step")
	t.assert_eq(burst.damage_at(burst.max_level), burst.damage + burst.damage_per_level * float(burst.max_level - 1),
		"max level applies every scaling step")

	var points_before: int = player.skill_points
	player.add_skill_points(burst.max_level)
	var level_before_spend: int = player.ability_level(burst)
	var successes := 0
	for _i in range(burst.max_level + 2):
		if player.spend_skill_point(burst):
			successes += 1
	t.assert_eq(player.ability_level(burst), burst.max_level, "abilities stop at their max level")
	t.assert_eq(successes, burst.max_level - level_before_spend, "extra spends past max are refused")
	t.assert_eq(player.skill_points, points_before + burst.max_level - successes, "refused spends cost nothing")

	player.add_skill_points(5)
	t.assert_true(player.spend_skill_point(storm), "spending works when unlocked")

	var gated := AbilityDefinition.new()
	gated.id = &"gated_test"
	gated.display_name = "Gated Test"
	gated.max_level = 3
	gated.unlock_level = 99
	t.assert_false(player.spend_skill_point(gated), "unlock level gates the spend")
	t.assert_eq(player.ability_level(gated), 1, "locked abilities do not advance")
	t.assert_false(player.can_spend_skill_point(gated), "gated abilities report unspendable")
	t.assert_true(player.can_spend_skill_point(burst) or player.skill_points == 0 or player.ability_level(burst) >= burst.max_level,
		"spendability reflects points, unlock and max")

	var total_spent: int = player.skill_points_spent
	var points_held: int = player.skill_points
	var refunded: int = player.reset_skills()
	t.assert_eq(refunded, total_spent, "reset refunds every spent point")
	t.assert_eq(player.skill_points, points_held + total_spent, "refunded points return to the pool")
	t.assert_eq(player.skill_points_spent, 0, "spent tracking clears")
	t.assert_eq(player.ability_level(burst), 1, "reset drops abilities to level 1")
	t.assert_eq(player.ability_level(storm), 1, "reset drops every ability")

	player.add_skill_points(2)
	t.assert_true(player.spend_skill_point(storm), "points can be spent again differently")
	t.assert_eq(player.ability_level(storm), 2, "re-spend raises the other ability")
	t.assert_eq(player.ability_level(burst), 1, "the first ability stays at base")
	var second_refund: int = player.reset_skills()
	t.assert_true(second_refund >= 1, "repeated resets refund again")
	t.assert_true(player.spend_skill_point(burst), "reset is unlimited")

	var max_hp_before: float = player.max_hp
	var level_before: int = player.level
	player.grant_xp(player.xp_to_next_level())
	t.assert_true(player.level > level_before, "killing-level flow still levels")
	t.assert_true(player.max_hp >= max_hp_before, "level scaling survives the skill system")
	t.assert_true(player.skill_points >= 0, "skill points never go negative")
	t.assert_eq(player.skill_points + player.skill_points_spent,
		points_held + total_spent + 2 + (player.level - level_before),
		"every point is accounted for (no dupes, no leaks)")

	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
