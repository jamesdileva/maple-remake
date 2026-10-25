extends RefCounted

func get_suite_name() -> String:
	return "fresh_player"

func run(t) -> void:
	TutorialSystem.reset()
	var game: Node2D = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	t.root.add_child(game)
	t.register_world(game)
	SpawnManager.enabled = false
	LootManager.enabled = false
	DebugManager.disable_ai = true
	await t.physics_frame
	await t.physics_frame

	var player: Player = game.get_node("Player")
	var picker := game.get_node_or_null("ClassSelect") as ClassSelectOverlay
	t.assert_true(picker != null, "a new player meets the class picker")
	if picker == null:
		t.complete_suite(get_suite_name())
		return
	t.assert_true(picker.visible, "the picker covers the first frame")
	t.assert_eq(picker.options_count(), 4, "all four classes are offered")
	var names := []
	for button in picker.options_container().get_children():
		if button is Button:
			names.append((button as Button).text)
	for name in ["Mage", "Warrior", "Archer", "Assassin"]:
		t.assert_true(names.any(func(text: String) -> bool: return text.begins_with(name)),
			"%s is a visible choice" % name)
	var first: Button = picker.options_container().get_child(0)
	t.assert_true(first.has_focus(), "the first class takes controller focus")

	var chosen: Array = []
	picker.class_chosen.connect(func(class_id: StringName): chosen.append(class_id))
	t.assert_true(picker.choose_class(&"warrior"), "the picker accepts a class")
	t.assert_eq(chosen, [&"warrior"], "the choice is announced")
	t.assert_eq(player.class_definition.id, &"warrior", "the hero becomes a warrior")
	t.assert_eq(player.ability_at(0).id, &"warrior_heavy_slash", "the kit swaps immediately")
	t.assert_true(not picker.visible, "the picker closes after choosing")

	var start_x := player.global_position.x
	Input.action_press("move_left")
	for _i in range(170):
		await t.physics_frame
	Input.action_release("move_left")
	t.assert_true(player.global_position.x < start_x - 100.0, "the hero runs on the first try")
	t.assert_true(TutorialSystem.is_seen(&"1_move"), "running teaches movement without docs")
	t.assert_true(game.get_node("Coach").current() != null, "the coach surfaces the lesson")

	player.global_position = Vector2(0.0, -60.0)
	player.velocity = Vector2.ZERO
	await t.physics_frame
	Input.action_press("jump")
	for _i in range(10):
		await t.physics_frame
	t.assert_true(player.global_position.y < -60.0, "the hero leaves the ground")
	for _i in range(65):
		await t.physics_frame
	Input.action_release("jump")
	t.assert_true(TutorialSystem.is_seen(&"2_jump"), "holding jump teaches the leap")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/meadow_slime.tres")
	var mob: Mob = mob_scene.instantiate()
	mob.definition = definition
	player.global_position = Vector2(0.0, -60.0)
	mob.global_position = Vector2(-34.0, -46.0)
	game.get_node("World").get_child(0).add_child(mob)
	await t.physics_frame
	await t.physics_frame
	var mob_hp := mob.hp
	Input.action_press("attack")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("attack")
	t.assert_true(mob.hp < mob_hp, "the basic attack connects")
	t.assert_true(TutorialSystem.is_seen(&"3_attack"), "the attack lesson lands")

	player.mana = player.max_mana
	player.global_position = Vector2(0.0, -60.0)
	mob.global_position = Vector2(-50.0, -46.0)
	var casts := []
	EventBus.ability_cast_completed.connect(func(ability: AbilityDefinition, _hits: int):
		casts.append(ability.id))
	Input.action_press("skill_1")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("skill_1")
	for _i in range(90):
		if not casts.is_empty():
			break
		await t.physics_frame
	t.assert_true(casts.has(&"warrior_heavy_slash"), "the first skill fires from the number row")
	t.assert_true(player.mana < player.max_mana, "the skill spends mana")

	LootManager.enabled = true
	var victim: Mob = mob_scene.instantiate()
	victim.definition = definition
	victim.global_position = Vector2(-40.0, -46.0)
	game.get_node("World").get_child(0).add_child(victim)
	await t.physics_frame
	await t.physics_frame
	var xp_before := player.xp
	victim.take_damage(999999.0, player)
	for _i in range(180):
		if player.inventory.currency > 0 or not player.inventory.items.is_empty():
			break
		await t.physics_frame
	t.assert_true(player.xp > xp_before, "the first kill grants xp")
	t.assert_true(player.inventory.currency > 0 or not player.inventory.items.is_empty(),
		"the first kill auto-loots")

	player.grant_xp(player.xp_to_next_level())
	t.assert_true(player.level >= 2, "the first level arrives quickly")
	t.assert_true(player.skill_points >= 1, "a level offers a skill point")

	t.assert_true(WorldManager.travel_to(&"sunlit_meadow", &"west"), "the east gate opens")
	await t.physics_frame
	await t.physics_frame
	t.assert_eq(WorldManager.current_map_id, &"sunlit_meadow", "the meadow becomes the world")
	t.assert_true(not picker.visible, "the class picker does not return mid-run")

	LootManager.enabled = false
	DebugManager.disable_ai = false
	game.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
