extends RefCounted

func get_suite_name() -> String:
	return "stress"

func run(t) -> void:
	var scene: PackedScene = load("res://scenes/lab/combat_lab.tscn")
	var lab_root: Node2D = scene.instantiate()
	t.root.add_child(lab_root)
	t.register_world(lab_root)
	await t.physics_frame
	await t.physics_frame

	var lab: CombatLab = lab_root.get_node("Lab")
	var player: Player = lab_root.get_node("Player")
	DebugManager.god_mode = true
	DebugManager.disable_ai = true
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0

	await _scenario(t, lab, player, "100_mobs", 100, "res://data/mobs/test_slime.tres")
	await _scenario(t, lab, player, "250_mobs", 250, "res://data/mobs/test_slime.tres")
	await _chain_scenario(t, lab, player)
	await _summon_scenario(t, lab, player)
	await _effects_scenario(t, lab, player)

	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	lab_root.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _scenario(t, lab: CombatLab, player: Player, label: String, count: int, mob_path: String) -> void:
	lab.reset_encounter()
	lab.set_mob(mob_path)
	_select_count(lab, count)
	player.mana = player.max_mana
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	var spawned: int = lab.spawn()
	t.assert_true(spawned >= count, "[%s] spawned the pack (%d)" % [label, spawned])
	_record_metrics(t, "%s_spawned" % label)
	var cleared: bool = await _cast_fma_until_clear(t, lab, player, 400)
	t.assert_true(cleared, "[%s] FMA clears the pack" % label)
	_record_metrics(t, "%s_cleared" % label)
	lab.reset_encounter()

func _chain_scenario(t, lab: CombatLab, player: Player) -> void:
	lab.reset_encounter()
	lab.set_mob("res://data/mobs/bomb_slime.tres")
	_select_count(lab, 10)
	player.mana = player.max_mana
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	var spawned: int = lab.spawn()
	t.assert_true(spawned >= 10, "[chain] spawned parents (%d)" % spawned)
	_record_metrics(t, "chain_spawned")
	var cleared: bool = await _cast_fma_until_clear(t, lab, player, 400)
	t.assert_true(cleared, "[chain] chain reactions resolve completely")
	_record_metrics(t, "chain_cleared")
	var stats: Dictionary = SpawnManager.stats()
	t.assert_true(stats.get("total", 0) <= SpawnManager.max_total_mobs, "[chain] entity budget held")
	lab.reset_encounter()

func _summon_scenario(t, lab: CombatLab, player: Player) -> void:
	lab.reset_encounter()
	player.mana = player.max_mana
	player.global_position = Vector2(300.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	Input.action_press("skill_5")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("skill_5")
	for _i in range(80):
		await t.physics_frame
		if not player.is_casting():
			break
	t.assert_true(player.active_summons() >= 1, "[summons] allies spawn under load")
	_record_metrics(t, "summons_active")
	for _i in range(1400):
		await t.physics_frame
		if player.active_summons() == 0:
			break
	t.assert_eq(player.active_summons(), 0, "[summons] allies expire without leaking")
	_record_metrics(t, "summons_expired")
	lab.reset_encounter()
	Input.action_release("skill_5")

func _effects_scenario(t, lab: CombatLab, player: Player) -> void:
	lab.reset_encounter()
	lab.set_mob("res://data/mobs/test_slime.tres")
	_select_count(lab, 50)
	player.mana = player.max_mana
	player.global_position = Vector2(0.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	lab.spawn()
	await _press_skill(t, "skill_4")
	t.assert_true(t.get_nodes_in_group("effects").size() > 0, "[effects] FMA produces effects")
	for _i in range(400):
		await t.physics_frame
		if t.get_nodes_in_group("effects").size() == 0 and not player.is_casting():
			break
	t.assert_eq(t.get_nodes_in_group("effects").size(), 0, "[effects] all effects clean up")
	_record_metrics(t, "effects_clean")
	lab.reset_encounter()
	Input.action_release("skill_4")

func _cast_fma_until_clear(t, lab: CombatLab, player: Player, max_frames: int) -> bool:
	for _i in range(3):
		player.mana = player.max_mana
		await _press_skill(t, "skill_4")
		for _f in range(max_frames):
			await t.physics_frame
			if not player.is_casting() and lab.lab_mob_count() == 0:
				return true
	return lab.lab_mob_count() == 0

func _press_skill(t, action: String) -> void:
	Input.action_press(action)
	for _i in range(3):
		await t.physics_frame
	Input.action_release(action)

func _select_count(lab: CombatLab, count: int) -> void:
	var option: OptionButton = lab.get_node("LabUI/Panel/VBox/CountOption")
	for index in range(option.item_count):
		if option.get_item_text(index) == str(count):
			option.select(index)
			return

func _record_metrics(t, label: String) -> void:
	var spawn_stats: Dictionary = SpawnManager.stats()
	DebugManager.register_combat_event("stress_probe", {
		"label": label,
		"active": spawn_stats.get("active", 0),
		"total": spawn_stats.get("total", 0),
		"enemies": t.get_nodes_in_group("enemies").size(),
		"effects": t.get_nodes_in_group("effects").size(),
		"fps": Engine.get_frames_per_second(),
		"frame_ms": DebugManager.frame_time_ms(),
		"memory_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
	})
	print("stress [%s]: enemies=%d effects=%d frame_ms=%.2f mem=%.1fMB" % [
		label,
		t.get_nodes_in_group("enemies").size(),
		t.get_nodes_in_group("effects").size(),
		DebugManager.frame_time_ms(),
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
	])
