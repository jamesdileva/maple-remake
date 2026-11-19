extends RefCounted

const ROOM := "res://scenes/maps/test_room.tscn"
const SLIME := "res://data/mobs/test_slime.tres"
const MOB_SCENE := "res://scenes/mobs/mob.tscn"
const REPORT_DIR := "user://debug/pacing_machinery_test"

func get_suite_name() -> String:
	return "pacing_machinery"

func run(t) -> void:
	_math_checks(t)
	await _bot_primitives(t)
	_writer_checks(t)
	t.complete_suite(get_suite_name())

func _math_checks(t) -> void:
	t.assert_almost_eq(PacingBot.minutes_for_xp(14400.0, 60.0), 4.0, 0.001,
		"14400 xp at 60 xp/s costs four minutes")
	t.assert_almost_eq(PacingBot.minutes_for_xp(6000.0, 1.0), 100.0, 0.001,
		"slow rates divide straight into minutes")
	t.assert_almost_eq(PacingBot.minutes_for_xp(3000.0, 0.0), 50.0, 0.001,
		"a dead rate clamps to the xp/s floor instead of dividing by zero")

func _bot_primitives(t) -> void:
	var room: Node2D = (load(ROOM) as PackedScene).instantiate()
	t.root.add_child(room)
	t.register_world(room)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame

	var bot := PacingBot.new()
	bot.tree = t
	bot.player = room.get_node("Player") as Player
	bot.world = room
	t.assert_true(bot.player != null, "the bot attaches to a real player")

	var start_x: float = bot.player.global_position.x
	var walk: Dictionary = await bot._walk_to_x(start_x + 300.0, 1200)
	t.assert_true(absf(bot.player.global_position.x - (start_x + 300.0)) <= PacingBot.ARRIVE_SLACK_PX,
		"the bot walks to a target x")
	t.assert_false(bool(walk["assisted"]), "flat ground needs no assist")
	t.assert_true(int(walk["frames"]) > 0, "walking burns game time frames")

	var mob: Mob = _spawn_slime(room, bot.player.global_position.x + 60.0)
	var xp_before: float = bot.player.xp
	var stop := func() -> bool: return not is_instance_valid(mob) or mob.is_dead()
	var engage: Dictionary = await bot._engage(900, stop, &"")
	t.assert_true(not is_instance_valid(mob) or mob.is_dead(),
		"the bot kills a spawned mob through the real pipeline")
	t.assert_true(bot.player.xp > xp_before, "the kill pays xp")
	t.assert_true(int(engage["frames"]) > 0, "engaging burns game time frames")

	bot.player.add_skill_points(3)
	var spent := bot._spend_points()
	t.assert_eq(spent, 3, "the bot spends every pending skill point on damage abilities")

	var leveled := []
	bot.player.leveled_up.connect(func(new_level: int): leveled.append(new_level))
	await bot._extrapolate_to(bot.player.level + 2, 60.0, {"levels": []})
	t.assert_true(leveled.size() >= 2, "the chunked grant loop levels naturally")
	t.assert_true(bot.player.level >= 2, "the extrapolated grind reaches the target level")
	t.assert_false(DebugManager.god_mode, "the extrapolation loop restores god mode")

	DebugManager.disable_ai = false
	DebugManager.god_mode = false
	LootManager.enabled = false
	room.queue_free()
	await t.physics_frame

func _spawn_slime(room: Node2D, x: float) -> Mob:
	var mob: Mob = (load(MOB_SCENE) as PackedScene).instantiate()
	mob.definition = load(SLIME) as MobDefinition
	room.add_child(mob)
	mob.global_position = Vector2(x, -46.0)
	return mob

func _writer_checks(t) -> void:
	var writer := PacingReportWriter.new()
	var results := [_synthetic_run("mage", 5400.0, true), _synthetic_run("warrior", 90000.0, true)]
	var report: Dictionary = writer.write(results, REPORT_DIR)
	t.assert_true(FileAccess.file_exists(report["json_path"]), "the writer emits json")
	t.assert_true(FileAccess.file_exists(report["md_path"]), "the writer emits markdown")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report["json_path"]))
	t.assert_true(parsed is Dictionary, "the json parses")
	if parsed is Dictionary:
		t.assert_true((parsed as Dictionary).has("classes"), "the json carries per-class results")
		t.assert_true(((parsed as Dictionary).get("findings", []) as Array).size() > 0, "the json ranks findings")
	var analysis: Dictionary = report
	t.assert_true(_class_hours(analysis, "mage") < PacingReportWriter.TARGET_HOURS_LOW,
		"the fast synthetic run reads below target")
	t.assert_true(_class_hours(analysis, "warrior") > PacingReportWriter.TARGET_HOURS_HIGH,
		"the slow synthetic run reads above target")
	t.assert_true(_has_flag(analysis, "mage", "overpowered"), "overpowered detection fires")
	t.assert_true(_has_flag(analysis, "mage", "boring"), "boring detection fires")
	t.assert_true(_has_flag(analysis, "warrior", "wall"), "wall detection fires")
	t.assert_true(_has_flag(analysis, "warrior", "friction"), "friction detection fires")
	var md := FileAccess.get_file_as_string(report["md_path"])
	t.assert_true(md.contains("Automated Pacing Report"), "the markdown opens with a title")
	t.assert_true(md.contains("Findings"), "the markdown lists findings")

func _class_hours(analysis: Dictionary, wanted_class: String) -> float:
	for entry: Dictionary in analysis.get("classes", []):
		if String(entry.get("class", "")) == wanted_class:
			return float(entry.get("game_hours", 0.0))
	return 0.0

func _has_flag(analysis: Dictionary, wanted_class: String, needle: String) -> bool:
	for entry: Dictionary in analysis.get("classes", []):
		if String(entry.get("class", "")) != wanted_class:
			continue
		for segment: Dictionary in entry.get("segments", []):
			for flag: String in segment.get("flags", []):
				if flag.contains(needle):
					return true
	return false

func _synthetic_run(class_id: String, game_seconds: float, completed: bool) -> Dictionary:
	return {
		"class": class_id,
		"completed": completed,
		"game_seconds": game_seconds,
		"final_level": 28,
		"advancement": {"advanced": true, "level": 20},
		"notes": [],
		"segments": [
			{
				"map": "sunlit_meadow", "recommended_level": 2, "arrival_level": 2, "target_level": 5,
				"transit_seconds": 14.0, "travel_method": "portal",
				"mobs": ["meadow_slime"], "avg_mob_hp": 26.0,
				"sample": {"kills": 25, "game_seconds": 12.0, "xp_per_sec": 12.0, "dps": 300.0,
					"casts": 9, "mana_downtime_seconds": 0.0, "damage_taken": 0.0, "deaths": 0},
				"levels": [{"level": 2, "minutes": 0.5}, {"level": 3, "minutes": 0.7}, {"level": 4, "minutes": 0.9}],
				"boss": null, "deaths": 0, "stuck": 0, "assists": 0, "accidental_travels": 0,
				"loot": ["rusty_blade"], "notes": [],
			},
			{
				"map": "whispering_forest", "recommended_level": 5, "arrival_level": 5, "target_level": 12,
				"transit_seconds": 18.0, "travel_method": "portal",
				"mobs": ["shade_moth", "thorn_crawler"], "avg_mob_hp": 30.0,
				"sample": {"kills": 25, "game_seconds": 25.0, "xp_per_sec": 10.0, "dps": 140.0,
					"casts": 20, "mana_downtime_seconds": 2.0, "damage_taken": 40.0, "deaths": 0},
				"levels": [{"level": 6, "minutes": 8.0}, {"level": 7, "minutes": 10.0}],
				"boss": null, "deaths": 0, "stuck": 0, "assists": 0, "accidental_travels": 0,
				"loot": [], "notes": [],
			},
			{
				"map": "haunted_fortress", "recommended_level": 24, "arrival_level": 20, "target_level": 24,
				"transit_seconds": 22.0, "travel_method": "portal",
				"mobs": ["night_stalker"], "avg_mob_hp": 120.0,
				"sample": {"kills": 18, "game_seconds": 40.0, "xp_per_sec": 20.0, "dps": 90.0,
					"casts": 30, "mana_downtime_seconds": 14.0, "damage_taken": 260.0, "deaths": 3},
				"levels": [{"level": 20, "minutes": 30.0}, {"level": 21, "minutes": 8.0}, {"level": 22, "minutes": 25.0}],
				"boss": {"id": "forge_warden", "recommended_level": 18, "attempts": 3, "deaths": 2,
					"kill_seconds": 45.0, "killed": true, "synthetic": false, "dps": 90.0,
					"damage_taken": 120.0, "game_seconds": 135.0},
				"deaths": 5, "stuck": 2, "assists": 2, "accidental_travels": 1,
				"loot": ["warden_plate"], "notes": [],
			},
		],
	}
