extends RefCounted

func get_suite_name() -> String:
	return "tutorial"

func run(t) -> void:
	TutorialSystem.reset()
	t.assert_eq(TutorialSystem.lesson_count(), 10, "ten data-driven lessons load")
	t.assert_eq(TutorialSystem.seen_count(), 0, "nothing is seen after reset")
	t.assert_eq(TutorialSystem.active_lesson(), null, "nothing is armed while idle")

	var game_scene: PackedScene = load("res://scenes/game/game.tscn")
	var game: Node2D = game_scene.instantiate()
	t.root.add_child(game)
	t.register_world(game)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame

	var player: Player = game.get_node("Player")
	var coach := game.get_node("Coach") as CoachOverlay
	t.assert_true(coach != null, "the coach overlay ships with the game")
	t.assert_true(TutorialSystem.is_playing, "booting the game starts the tutorial")
	t.assert_true(TutorialSystem.active_lesson() != null, "the first lesson arms itself")
	t.assert_eq(TutorialSystem.active_lesson().id, &"1_move", "movement teaches first")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0

	var taught: Array = []
	TutorialSystem.lesson_triggered.connect(func(lesson: LessonDefinition): taught.append(lesson.id))

	Input.action_press("move_left")
	for _i in range(170):
		await t.physics_frame
	Input.action_release("move_left")
	t.assert_true(TutorialSystem.is_seen(&"1_move"), "holding run completes the move lesson")
	t.assert_eq(coach.current().id, &"1_move", "the coach shows the completed lesson")
	t.assert_true(coach.get_node("TipPanel").visible, "the tip panel is visible")
	t.assert_eq(coach.get_node("TipPanel/VBox/Title").text, "Walk The Meadow", "the tip title matches data")

	player.global_position = Vector2(-1050.0, -60.0)
	await t.physics_frame
	Input.action_press("jump")
	for _i in range(75):
		await t.physics_frame
	Input.action_release("jump")
	t.assert_true(TutorialSystem.is_seen(&"2_jump"), "holding jump completes the jump lesson")

	Input.action_press("attack")
	await t.physics_frame
	await t.physics_frame
	Input.action_release("attack")
	t.assert_true(TutorialSystem.is_seen(&"3_attack"), "one swing completes the attack lesson")

	player.mana = player.max_mana
	Input.action_press("skill_1")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("skill_1")
	for _i in range(60):
		if TutorialSystem.is_seen(&"4_cast"):
			break
		await t.physics_frame
	t.assert_true(TutorialSystem.is_seen(&"4_cast"), "one cast completes the casting lesson")

	player.mana = player.max_mana
	Input.action_press("skill_4")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("skill_4")
	for _i in range(120):
		if TutorialSystem.is_seen(&"5_fma"):
			break
		await t.physics_frame
	t.assert_true(TutorialSystem.is_seen(&"5_fma"), "one full-map blast teaches the FMA lesson")
	t.assert_eq(coach.current().id, &"5_fma", "the coach follows the latest lesson")

	for _i in range(220):
		if TutorialSystem.is_seen(&"6_mana"):
			break
		await t.physics_frame
	t.assert_true(TutorialSystem.is_seen(&"6_mana"), "the mana tip arrives on its own timer")
	for _i in range(280):
		if TutorialSystem.is_seen(&"7_skills"):
			break
		await t.physics_frame
	t.assert_true(TutorialSystem.is_seen(&"7_skills"), "the skill tip arrives on its own timer")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var bomb: Mob = mob_scene.instantiate()
	bomb.definition = load("res://data/mobs/bomb_slime.tres") as MobDefinition
	bomb.global_position = Vector2(-900.0, -40.0)
	game.get_node("World").get_child(0).add_child(bomb)
	await t.physics_frame
	await t.physics_frame
	bomb.take_damage(9999.0, player)
	await t.physics_frame
	await t.physics_frame
	t.assert_true(TutorialSystem.is_seen(&"8_chains"), "a bursting chain mob teaches chains")

	for _i in range(220):
		if TutorialSystem.is_seen(&"9_loot"):
			break
		await t.physics_frame
	t.assert_true(TutorialSystem.is_seen(&"9_loot"), "the loot tip arrives on its own timer")

	player.set_level(20)
	t.assert_true(player.advance(), "the player can advance for the final lesson")
	for _i in range(10):
		await t.physics_frame
	t.assert_true(TutorialSystem.is_seen(&"10_advance"), "advancing teaches the advancement lesson")

	for _i in range(10):
		await t.physics_frame
	t.assert_eq(TutorialSystem.active_lesson(), null, "a finished tutorial arms nothing")
	t.assert_eq(TutorialSystem.seen_count(), 10, "all ten lessons are seen")
	t.assert_eq(taught.size(), 10, "every lesson fires exactly once")

	t.assert_false(TutorialSystem.complete_external(&"nope"), "unknown lessons cannot complete")
	t.assert_false(TutorialSystem.complete_external(&"1_move"), "seen lessons cannot repeat")

	var path: String = DebugManager.export_debug_data()
	t.assert_true(FileAccess.get_file_as_string(path).contains("tutorial"), "the snapshot exposes tutorial progress")

	TutorialSystem.reset()
	t.assert_eq(TutorialSystem.seen_count(), 0, "reset clears the tutorial")
	t.assert_false(TutorialSystem.is_playing, "reset idles the system")

	SpawnManager.enabled = false
	LootManager.enabled = false
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	game.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())
