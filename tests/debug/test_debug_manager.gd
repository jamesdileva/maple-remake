extends RefCounted

func get_suite_name() -> String:
	return "debug_manager"

func run(t) -> void:
	await t.process_frame
	await t.process_frame
	var manager: Node = t.root.get_node_or_null("DebugManager")
	t.assert_true(manager != null, "DebugManager autoload exists")
	t.assert_true(manager.is_enabled(), "debug enabled via project setting")

	manager.reset_counters()
	t.assert_eq(manager.counters.damage_dealt, 0.0, "counters reset")
	manager.register_combat_event("damage_dealt", {"amount": 250.0, "is_crit": true})
	manager.register_combat_event("damage_dealt", {"amount": 50.0})
	manager.register_combat_event("kill", {})
	manager.register_combat_event("cast", {"ability": "test_ability"})
	manager.register_combat_event("death", {})
	t.assert_eq(manager.counters.damage_dealt, 300.0, "damage accumulates")
	t.assert_eq(manager.counters.crits, 1, "crit counted")
	t.assert_eq(manager.counters.kills, 1, "kills counted")
	t.assert_eq(manager.counters.casts, 1, "casts counted")
	t.assert_eq(manager.counters.deaths, 1, "deaths counted")

	manager.god_mode = true
	t.assert_true(manager.is_invulnerable(), "god mode => invulnerable")
	manager.toggle_god_mode()
	t.assert_false(manager.god_mode, "toggle god mode off")

	t.assert_true(not t.debug_collisions_hint, "hitbox debug hint starts off")
	manager.toggle_show_hitboxes()
	t.assert_true(t.debug_collisions_hint, "show hitboxes toggles SceneTree debug hint")
	manager.toggle_show_hitboxes()
	t.assert_false(t.debug_collisions_hint, "show hitboxes toggles back")

	var error: Error = manager.reload_scene()
	t.assert_true(error == OK or error == ERR_UNCONFIGURED, "reload_scene safe without current scene")
	t.assert_false(manager.teleport_player(Vector2(10.0, 10.0)), "teleport fails without player")
	t.assert_eq(manager.current_scene_path(), "—", "current_scene_path placeholder without scene")

	manager._track_frame_time(0.016)
	var stats: Dictionary = manager.frame_time_stats()
	t.assert_true(stats.samples >= 1, "frame stats recorded")

	var counts: Dictionary = manager.entity_counts()
	t.assert_true(counts.has("enemies") and counts.enemies == 0, "entity counts empty in test scene")

	var path: String = manager.export_debug_data()
	t.assert_true(path != "", "export_debug_data returns a path")
	t.assert_true(FileAccess.file_exists(path), "snapshot file written")
	var snapshot_text := FileAccess.get_file_as_string(path)
	t.assert_true(snapshot_text.contains("counters"), "snapshot contains counters")
	t.assert_true(snapshot_text.contains("damage_dealt"), "snapshot contains damage_dealt")

	# the party surface is inspectable: an advanced player reports every aura field
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	await t.physics_frame
	await t.physics_frame
	var probe: Player = world.get_node("Player")
	probe.set_level(25)
	probe.advance()
	probe.apply_class(load("res://data/classes/assassin.tres") as ClassDefinition)
	var party_path: String = manager.export_debug_data()
	var party_text := FileAccess.get_file_as_string(party_path)
	t.assert_true(party_text.contains("party_alacrity"), "snapshot exposes the alacrity aura")
	t.assert_true(party_text.contains("unique_classes"), "snapshot exposes the unique class count")
	t.assert_true(party_text.contains("party_xp_multiplier"), "snapshot exposes the party xp multiplier")
	t.assert_true(party_text.contains("party_tactics"), "snapshot exposes the tactics aura")
	world.queue_free()
	await t.process_frame
	await t.physics_frame
	t.assert_true(not is_instance_valid(world), "the probe world is torn down before the suite ends")

	var log_path: String = manager._log.file_path()
	t.assert_true(log_path != "", "debug log file path set")
	t.assert_true(FileAccess.file_exists(log_path), "jsonl debug log written")
	var log_text := FileAccess.get_file_as_string(log_path)
	t.assert_true(log_text.contains("session_start"), "log contains session_start")
	t.assert_true(log_text.contains("damage_dealt"), "log contains damage_dealt event")
	t.assert_true(JSON.parse_string(log_text.split("\n")[0]) != null, "log lines are valid JSON")

	await _test_overlay(t, manager)

func _test_overlay(t, manager: Node) -> void:
	var overlay: CanvasLayer = manager._overlay
	t.assert_true(overlay != null, "manager created its overlay")
	await t.process_frame
	await t.process_frame
	await t.create_timer(0.25).timeout

	t.assert_true(overlay.visible, "overlay starts visible")
	var stats_label: Label = overlay.get_node("%StatsLabel")
	t.assert_true(stats_label.text.contains("FPS"), "stats label shows FPS")
	t.assert_true(stats_label.text.contains("enemies"), "stats label shows entity counts")
	t.assert_true(stats_label.text.contains("scene"), "stats label shows current scene")

	var flags_label: Label = overlay.get_node("%FlagsLabel")
	t.assert_true(flags_label.text.contains("GOD"), "flags label shows god flag")

	manager.god_mode = true
	overlay._on_god_button_pressed()
	t.assert_false(manager.god_mode, "god button toggles flag off")
	overlay._on_console_submitted("god")
	t.assert_true(manager.god_mode, "console 'god' toggles flag on")
	manager.god_mode = false

	overlay._on_console_submitted("tp 100 200")
	var result_label: Label = overlay.get_node("%ResultLabel")
	t.assert_true(result_label.text.contains("teleport"), "console tp gives feedback without player")

	overlay._on_console_submitted("killall")
	t.assert_true(result_label.text.contains("kill"), "console killall gives feedback")

	overlay._on_console_submitted("help")
	t.assert_true(result_label.text.contains("commands"), "console help lists commands")

	overlay._on_console_submitted("nonsense")
	t.assert_true(result_label.text.contains("unknown"), "console reports unknown commands")

	manager.toggle_overlay()
	t.assert_false(overlay.visible, "overlay toggles off")
	manager.toggle_overlay()
	t.assert_true(overlay.visible, "overlay toggles on")
	t.complete_suite(get_suite_name())
