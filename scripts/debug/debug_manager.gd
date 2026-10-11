extends Node

const TELEMETRY_SAMPLES := 120
const OVERLAY_SCENE_PATH := "res://scenes/debug/debug_overlay.tscn"

var god_mode := false
var infinite_mana := false
var force_crit := false
var show_hitboxes := false
var disable_ai := false

var counters := {
	"damage_dealt": 0.0,
	"damage_taken": 0.0,
	"crits": 0,
	"kills": 0,
	"casts": 0,
	"deaths": 0,
}

var _log: DebugLog
var _overlay: CanvasLayer
var _frame_times := PackedFloat32Array()
var _frame_time_index := 0
var _frame_time_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log = DebugLog.new()
	_frame_times.resize(TELEMETRY_SAMPLES)
	_register_custom_monitors()
	if is_enabled():
		_set_hitboxes_debug(false)
		_create_overlay()
	_get_log().log_event("session_start", _snapshot_config())

func _exit_tree() -> void:
	if _log != null:
		_get_log().close()

func is_enabled() -> bool:
	return bool(ProjectSettings.get_setting("game/debug/enabled", true))

func is_invulnerable() -> bool:
	return is_enabled() and god_mode

func toggle_god_mode() -> void:
	god_mode = not god_mode
	_get_log().log_event("flag_god_mode", {"value": god_mode})

func toggle_infinite_mana() -> void:
	infinite_mana = not infinite_mana
	_get_log().log_event("flag_infinite_mana", {"value": infinite_mana})

func toggle_show_hitboxes() -> void:
	show_hitboxes = not show_hitboxes
	_set_hitboxes_debug(show_hitboxes)
	_get_log().log_event("flag_show_hitboxes", {"value": show_hitboxes})

func toggle_force_crit() -> void:
	force_crit = not force_crit
	_get_log().log_event("flag_force_crit", {"value": force_crit})

func toggle_disable_ai() -> void:
	disable_ai = not disable_ai
	_get_log().log_event("flag_disable_ai", {"value": disable_ai})

func kill_all_enemies() -> int:
	if not is_enabled() or get_tree() == null:
		return 0
	var killed := 0
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if enemy.has_method("apply_debug_kill"):
			enemy.apply_debug_kill()
			killed += 1
	_get_log().log_event("debug_kill_all", {"killed": killed})
	return killed

func reload_scene() -> Error:
	if not is_enabled() or get_tree() == null:
		return ERR_UNCONFIGURED
	var error := get_tree().reload_current_scene()
	if error != OK:
		_get_log().log_event("debug_reload_failed", {"error": error})
	return error

func teleport_player(position: Vector2) -> bool:
	var player := find_player()
	if player == null:
		return false
	player.global_position = position
	_get_log().log_event("debug_teleport", {"x": position.x, "y": position.y})
	return true

func find_player() -> Node2D:
	if get_tree() == null:
		return null
	var player: Node = get_tree().get_first_node_in_group("player")
	return player as Node2D

func current_scene_path() -> String:
	if get_tree() == null or get_tree().current_scene == null:
		return "—"
	return get_tree().current_scene.scene_file_path

func register_combat_event(kind: String, data: Dictionary = {}) -> void:
	match kind:
		"damage_dealt":
			counters.damage_dealt += float(data.get("amount", 0.0))
			if data.get("is_crit", false):
				counters.crits += 1
		"damage_taken":
			counters.damage_taken += float(data.get("amount", 0.0))
		"kill":
			counters.kills += 1
		"cast":
			counters.casts += 1
		"death":
			counters.deaths += 1
	_get_log().log_event(kind, data)

func reset_counters() -> void:
	counters.damage_dealt = 0.0
	counters.damage_taken = 0.0
	counters.crits = 0
	counters.kills = 0
	counters.casts = 0
	counters.deaths = 0
	_get_log().log_event("counters_reset", {})

func frame_time_ms() -> float:
	return float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0

func frame_time_stats() -> Dictionary:
	if _frame_time_count == 0:
		return {"avg": 0.0, "min": 0.0, "max": 0.0, "samples": 0}
	var lowest := _frame_times[0]
	var highest := _frame_times[0]
	var total := 0.0
	for index in range(_frame_time_count):
		var sample := _frame_times[index]
		total += sample
		lowest = min(lowest, sample)
		highest = max(highest, sample)
	return {
		"avg": total / float(_frame_time_count),
		"min": lowest,
		"max": highest,
		"samples": _frame_time_count,
	}

func entity_counts() -> Dictionary:
	if get_tree() == null:
		return {"enemies": 0, "projectiles": 0, "effects": 0, "players": 0}
	return {
		"enemies": get_tree().get_nodes_in_group("enemies").size(),
		"projectiles": get_tree().get_nodes_in_group("projectiles").size(),
		"effects": get_tree().get_nodes_in_group("effects").size(),
		"players": get_tree().get_nodes_in_group("player").size(),
	}

func export_debug_data() -> String:
	var directory := DirAccess.open("user://")
	if directory == null:
		return ""
	directory.make_dir_recursive("debug")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://debug/snapshot_%s.json" % stamp
	var snapshot := {
		"exported_at": Time.get_datetime_string_from_system(),
		"engine": Engine.get_version_info(),
		"scene": current_scene_path(),
		"uptime_ms": Time.get_ticks_msec(),
		"debug_enabled": is_enabled(),
		"flags": {
			"god_mode": god_mode,
			"infinite_mana": infinite_mana,
			"force_crit": force_crit,
			"show_hitboxes": show_hitboxes,
			"disable_ai": disable_ai,
		},
		"counters": counters,
		"performance": {
			"fps": Engine.get_frames_per_second(),
			"frame_ms": frame_time_ms(),
			"frame_stats": frame_time_stats(),
			"static_memory_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
			"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		},
		"entity_counts": entity_counts(),
		"spawner": _spawner_stats(),
		"loot": _loot_stats(),
		"player_position": _player_position(),
		"recent_events": _get_log().recent_events(25),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[debug] cannot write snapshot: %s" % path)
		return ""
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	_get_log().log_event("debug_export", {"path": path})
	return path

func set_overlay_visible(visible: bool) -> void:
	if _overlay != null:
		_overlay.visible = visible

func toggle_overlay() -> void:
	if _overlay != null:
		_overlay.visible = not _overlay.visible

func _create_overlay() -> void:
	if not ResourceLoader.exists(OVERLAY_SCENE_PATH):
		push_warning("[debug] overlay scene missing: %s" % OVERLAY_SCENE_PATH)
		return
	var packed: PackedScene = load(OVERLAY_SCENE_PATH)
	_overlay = packed.instantiate()
	_overlay.visible = bool(ProjectSettings.get_setting("game/debug/overlay_visible", true))
	add_child(_overlay)

func _register_custom_monitors() -> void:
	Performance.add_custom_monitor("game/mobs", _monitor_group_count.bind("enemies"))
	Performance.add_custom_monitor("game/projectiles", _monitor_group_count.bind("projectiles"))
	Performance.add_custom_monitor("game/effects", _monitor_group_count.bind("effects"))
	Performance.add_custom_monitor("game/damage_dealt", _monitor_counter.bind("damage_dealt"))
	Performance.add_custom_monitor("game/kills", _monitor_counter.bind("kills"))

func _get_log() -> DebugLog:
	if _log == null:
		_log = DebugLog.new()
	return _log

func _monitor_group_count(group: String) -> int:
	if get_tree() == null:
		return 0
	return get_tree().get_nodes_in_group(group).size()

func _monitor_counter(key: String) -> float:
	return float(counters.get(key, 0))

func _spawner_stats() -> Dictionary:
	var spawner: Node = get_tree().root.get_node_or_null("SpawnManager")
	if spawner != null and spawner.has_method("stats"):
		return spawner.stats()
	return {}

func _loot_stats() -> Dictionary:
	var loot: Node = get_tree().root.get_node_or_null("LootManager")
	if loot != null and loot.has_method("stats"):
		var data: Dictionary = loot.stats()
		var player := find_player()
		if player != null and player.has_method("get_inventory"):
			data["currency"] = player.get_inventory().currency
			data["items"] = player.get_inventory().items
		return data
	return {}

func _player_position() -> Dictionary:
	var player := find_player()
	if player == null:
		return {"x": 0.0, "y": 0.0, "found": false}
	var data := {
		"x": player.global_position.x,
		"y": player.global_position.y,
		"found": true,
	}
	for key: String in ["hp", "max_hp", "mana", "max_mana"]:
		var value = player.get(key)
		if value != null:
			data[key] = value
	if player.has_method("level_progress"):
		data["level"] = player.get("level")
		data["xp"] = player.get("xp")
		data["xp_into_level"] = player.call("xp_into_level")
		data["xp_to_next_level"] = player.call("xp_to_next_level")
		data["skill_points"] = player.get("skill_points")
		data["skill_points_spent"] = player.get("skill_points_spent")
		data["ability_levels"] = player.get("ability_levels")
	if player.has_method("equipped_in"):
		var worn := {}
		for slot_name in [&"weapon", &"top", &"bottom", &"helmet"]:
			var item: EquipmentDefinition = player.equipped_in(slot_name)
			worn[slot_name] = item.id if item != null else ""
		data["equipment"] = worn
		data["equipment_power"] = player.equipment_power()
	if player.has_method("is_casting"):
		data["casting"] = player.current_ability().id if player.current_ability() != null else ""
		data["cast_progress"] = player.cast_progress()
	return data

func _snapshot_config() -> Dictionary:
	return {
		"engine": Engine.get_version_info().get("string", "unknown"),
		"debug_enabled": is_enabled(),
		"overlay_visible": ProjectSettings.get_setting("game/debug/overlay_visible", true),
		"log_to_file": ProjectSettings.get_setting("game/debug/log_to_file", true),
		"action_count": InputMap.get_actions().size(),
		"scene": current_scene_path(),
	}

func _set_hitboxes_debug(enabled: bool) -> void:
	if get_tree() != null:
		get_tree().debug_collisions_hint = enabled

func _process(_delta: float) -> void:
	if not is_enabled():
		return
	_track_frame_time(_delta)
	_handle_hotkeys()

func _track_frame_time(delta: float) -> void:
	var frame_ms := delta * 1000.0
	_frame_times[_frame_time_index] = frame_ms
	_frame_time_index = (_frame_time_index + 1) % TELEMETRY_SAMPLES
	_frame_time_count = min(_frame_time_count + 1, TELEMETRY_SAMPLES)

func _handle_hotkeys() -> void:
	if Input.is_action_just_pressed("debug_overlay"):
		toggle_overlay()
	if Input.is_action_just_pressed("debug_god"):
		toggle_god_mode()
	if Input.is_action_just_pressed("debug_kill_all"):
		kill_all_enemies()
	if Input.is_action_just_pressed("debug_reload_scene"):
		reload_scene()
	if Input.is_action_just_pressed("debug_export"):
		export_debug_data()
