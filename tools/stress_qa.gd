extends SceneTree

## Sprint 16.2 stress QA: profiles the roadmap scenarios (100/250 mobs,
## chain explosions, summons, FMA pipeline, boss effects) at honest wall
## time and reports bottlenecks. Writes
## user://debug/stress_report_<stamp>.json.
##   godot --headless --script tools/stress_qa.gd

const SCENARIO_FRAMES := 600
const BUDGET_MS := 16.6
const MOB_SCENE := "res://scenes/mobs/mob.tscn"
const BOSS_SCENE := "res://scenes/bosses/boss.tscn"

var _dm: Node

func _initialize() -> void:
	Engine.time_scale = 1.0
	_dm = root.get_node("DebugManager")
	var lab_root: Node2D = (load("res://scenes/lab/combat_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab_root)
	await physics_frame
	await physics_frame
	var lab = lab_root.get_node("Lab")
	var player = lab_root.get_node("Player")
	_dm.set("god_mode", true)
	lab.set_class(load("res://data/classes/mage.tres"))
	lab.set_level(40)
	lab.set_gear("res://data/equipment/sanctum_staff.tres")
	player.crit_chance = 0.0

	var scenarios := []
	scenarios.append(await _profile(lab, player, "fma_pipeline", func() -> void:
		_spawn_pack(lab_root, "res://data/mobs/benchmark_construct.tres", 20, Vector2(-500.0, -46.0))
		player.global_position = Vector2(0.0, -60.0)))
	scenarios.append(await _profile(lab, player, "mobs_100", func() -> void:
		_spawn_pack(lab_root, "res://data/mobs/miner_golem.tres", 100, Vector2(-900.0, -46.0))
		player.global_position = Vector2(0.0, -60.0)))
	scenarios.append(await _profile(lab, player, "mobs_250", func() -> void:
		_spawn_pack(lab_root, "res://data/mobs/miner_golem.tres", 250, Vector2(-1200.0, -46.0))
		player.global_position = Vector2(0.0, -60.0)))
	scenarios.append(await _profile(lab, player, "chain_explosions", func() -> void:
		_spawn_pack(lab_root, "res://data/mobs/bomb_slime.tres", 60, Vector2(-400.0, -46.0))
		player.global_position = Vector2(0.0, -60.0)))
	scenarios.append(await _profile(lab, player, "summons_250", func() -> void:
		_spawn_pack(lab_root, "res://data/mobs/miner_golem.tres", 250, Vector2(-1200.0, -46.0))
		player.global_position = Vector2(0.0, -60.0)
		await _cast_summons(self, player)))
	scenarios.append(await _profile(lab, player, "boss_effects", func() -> void:
		_spawn_boss(lab_root, "res://data/bosses/blightheart.tres", Vector2(240.0, -40.0))
		player.global_position = Vector2(0.0, -60.0)))

	_clear_field(lab)
	_dm.set("god_mode", false)

	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace(" ", "_")
	var path := "user://debug/stress_report_%s.json" % stamp
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"generated": Time.get_datetime_string_from_system(),
			"context": "headless (no renderer): frame costs are simulation wall cost, not player-facing fps",
			"budget_ms": BUDGET_MS,
			"scenarios": scenarios,
		}, "  "))
		file.close()

	var ranked := scenarios.duplicate()
	ranked.sort_custom(func(a, b): return float(a["avg_ms"]) > float(b["avg_ms"]))
	print("stress_qa: scenario | avg ms | p95 ms | max ms | budget | memory mb")
	for entry: Dictionary in ranked:
		var over := float(entry["avg_ms"]) > BUDGET_MS
		print("stress_qa: %-18s %6.1f %6.1f %6.1f   %s    %6.1f %s" % [
			str(entry["label"]), float(entry["avg_ms"]), float(entry["p95_ms"]),
			float(entry["max_ms"]), "OVER" if over else "ok",
			float(entry["memory_mb"]),
			"  <- BOTTLENECK" if over else ""])
	print("stress_qa: report -> %s" % path)
	print("stress_qa: bottleneck = %s (%.1f ms avg vs %.1f ms budget)" % [
		str(ranked[0]["label"]), float(ranked[0]["avg_ms"]), BUDGET_MS])
	quit(0)

func _profile(lab, player, label: String, setup: Callable) -> Dictionary:
	lab.reset_encounter()
	await physics_frame
	setup.call()
	await physics_frame
	await physics_frame
	var samples: Array = []
	await _rotate(player, SCENARIO_FRAMES, samples)
	var metrics := _summarize(samples)
	_clear_field(lab)
	await physics_frame
	return {
		"label": label,
		"avg_ms": metrics["avg"],
		"p95_ms": metrics["p95"],
		"max_ms": metrics["max"],
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"frames": int(metrics["frames"]),
	}

func _rotate(player, frames: int, samples: Array) -> void:
	var elapsed := 0
	while elapsed < frames:
		await physics_frame
		elapsed += 1
		samples.append(_dm.frame_time_ms())
		if player.is_casting():
			continue
		player.mana = player.max_mana
		Input.action_press("skill_4")
		for _i in range(3):
			await physics_frame
			elapsed += 1
			samples.append(_dm.frame_time_ms())
		Input.action_release("skill_4")

func _summarize(samples: Array) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in sorted:
		total += value
	return {
		"avg": total / maxf(1.0, float(sorted.size())),
		"p95": sorted[int(float(sorted.size()) * 0.95)],
		"max": sorted[sorted.size() - 1],
		"frames": sorted.size(),
	}

func _spawn_pack(parent: Node, mob_path: String, count: int, origin: Vector2) -> void:
	var definition = load(mob_path)
	var scene := load(MOB_SCENE) as PackedScene
	for index in range(count):
		var mob := scene.instantiate()
		mob.definition = definition
		parent.add_child(mob)
		var angle := TAU * float(index) / float(count)
		mob.global_position = origin + Vector2(cos(angle), sin(angle) * 0.3) * float(index % 20 + 6) * 12.0

func _spawn_boss(parent: Node, boss_path: String, position: Vector2) -> void:
	var boss = (load(BOSS_SCENE) as PackedScene).instantiate()
	boss.definition = load(boss_path)
	parent.add_child(boss)
	boss.global_position = position

func _cast_summons(tree: SceneTree, player) -> void:
	for _attempt in range(6):
		if player.active_summons() >= player.max_summons:
			break
		player.mana = player.max_mana
		Input.action_press("skill_5")
		for _i in range(3):
			await tree.physics_frame
		Input.action_release("skill_5")
		for _i in range(90):
			await tree.physics_frame
			if not player.is_casting():
				break

func _clear_field(lab) -> void:
	lab.reset_encounter()
	for mob: Object in get_nodes_in_group("enemies"):
		if is_instance_valid(mob):
			mob.queue_free()
	for effect: Object in get_nodes_in_group("effects"):
		if is_instance_valid(effect):
			effect.queue_free()
	await physics_frame
	await physics_frame
