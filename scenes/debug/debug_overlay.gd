class_name DebugOverlay
extends CanvasLayer

const UPDATE_INTERVAL := 0.1

@onready var _stats_label: Label = %StatsLabel
@onready var _flags_label: Label = %FlagsLabel
@onready var _counters_label: Label = %CountersLabel
@onready var _result_label: Label = %ResultLabel
@onready var _console_input: LineEdit = %ConsoleInput

var _update_accum := 0.0

func _ready() -> void:
	_ignore_mouse_on_containers()
	%GodButton.pressed.connect(_on_god_button_pressed)
	%ManaButton.pressed.connect(_on_mana_button_pressed)
	%CritButton.pressed.connect(_on_crit_button_pressed)
	%HitboxButton.pressed.connect(_on_hitbox_button_pressed)
	%KillAllButton.pressed.connect(_on_kill_all_button_pressed)
	%ReloadButton.pressed.connect(_on_reload_button_pressed)
	%ExportButton.pressed.connect(_on_export_button_pressed)
	_console_input.text_submitted.connect(_on_console_submitted)
	_refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	_update_accum += delta
	if _update_accum >= UPDATE_INTERVAL:
		_update_accum = 0.0
		_refresh()

func _on_god_button_pressed() -> void:
	DebugManager.toggle_god_mode()
	_show_result("god mode: %s" % _on_off(DebugManager.god_mode))

func _on_mana_button_pressed() -> void:
	DebugManager.toggle_infinite_mana()
	_show_result("infinite mana: %s" % _on_off(DebugManager.infinite_mana))

func _on_crit_button_pressed() -> void:
	DebugManager.toggle_force_crit()
	_show_result("force crit: %s" % _on_off(DebugManager.force_crit))

func _on_hitbox_button_pressed() -> void:
	DebugManager.toggle_show_hitboxes()
	_show_result("show hitboxes: %s" % _on_off(DebugManager.show_hitboxes))

func _on_kill_all_button_pressed() -> void:
	var killed := DebugManager.kill_all_enemies()
	_show_result("kill all: %d enemies" % killed)

func _on_reload_button_pressed() -> void:
	var error := DebugManager.reload_scene()
	_show_result("reload scene: %s" % error_string(error))

func _on_export_button_pressed() -> void:
	var path := DebugManager.export_debug_data()
	_show_result("exported: %s" % path)

func _on_console_submitted(command: String) -> void:
	_console_input.clear()
	_show_result("> %s" % command)
	var tokens := command.strip_edges().split(" ", false)
	if tokens.is_empty():
		return
	match tokens[0]:
		"god":
			DebugManager.toggle_god_mode()
			_show_result("god mode: %s" % _on_off(DebugManager.god_mode))
		"mana":
			DebugManager.toggle_infinite_mana()
			_show_result("infinite mana: %s" % _on_off(DebugManager.infinite_mana))
		"crit":
			DebugManager.toggle_force_crit()
			_show_result("force crit: %s" % _on_off(DebugManager.force_crit))
		"hitbox", "hitboxes":
			DebugManager.toggle_show_hitboxes()
			_show_result("show hitboxes: %s" % _on_off(DebugManager.show_hitboxes))
		"killall", "kill_all":
			var killed := DebugManager.kill_all_enemies()
			_show_result("kill all: %d enemies" % killed)
		"xp", "add_xp":
			if tokens.size() < 2:
				_show_result("usage: xp <amount>")
				return
			var player: Node = DebugManager.find_player()
			if player == null or not player.has_method("grant_xp"):
				_show_result("xp: no player found")
				return
			var amount := float(tokens[1])
			player.grant_xp(amount)
			_show_result("xp +%.0f → lv %d (%.0f/%s)" % [
				amount, player.get("level"), player.get("xp"),
				"MAX" if player.get("xp_table") and player.xp_table.is_max_level(player.get("level")) else "%.0f" % player.call("xp_to_next_level"),
			])
		"points", "add_points":
			if tokens.size() < 2:
				_show_result("usage: points <count>")
				return
			var player: Node = DebugManager.find_player()
			if player == null or not player.has_method("add_skill_points"):
				_show_result("points: no player found")
				return
			player.add_skill_points(int(float(tokens[1])))
			_show_result("skill points: %d" % player.get("skill_points"))
		"gear", "equip_gear":
			var test_player: Node = DebugManager.find_player()
			if test_player == null or not test_player.has_method("equip"):
				_show_result("gear: no player found")
				return
			var equipped := 0
			for gear_id: String in ["iron_sword", "cloth_tunic", "traveler_pants", "cloth_cap"]:
				var gear: EquipmentDefinition = load("res://data/equipment/%s.tres" % gear_id)
				if gear != null and test_player.level >= gear.level_requirement:
					test_player.equip(gear)
					equipped += 1
			_show_result("equipped %d test items (power %d)" % [equipped, test_player.equipment_power()])
		"save":
			var save_error: Error = SaveSystem.save_game(_current_payload())
			_show_result("save: %s (v%d)" % [error_string(save_error), SaveSystem.version()])
		"load":
			var payload := SaveSystem.load_game()
			if payload.is_empty():
				_show_result("load failed: %s" % SaveSystem.last_error)
				return
			var load_player: Node = DebugManager.find_player()
			if load_player == null or not load_player.has_method("restore_state"):
				_show_result("load: no player found")
				return
			load_player.restore_state(payload)
			_show_result("loaded: lv %d, %d gold" % [load_player.get("level"), load_player.get_inventory().currency])
		"reset_save":
			SaveSystem.delete_save()
			_show_result("save deleted")
		"reload":
			_show_result("reload scene: %s" % error_string(DebugManager.reload_scene()))
		"export":
			_show_result("exported: %s" % DebugManager.export_debug_data())
		"fps":
			_show_result("fps: %d" % Engine.get_frames_per_second())
		"tp", "teleport":
			if tokens.size() < 3:
				_show_result("usage: tp <x> <y>")
				return
			var position := Vector2(float(tokens[1]), float(tokens[2]))
			if DebugManager.teleport_player(position):
				_show_result("teleport to (%d, %d)" % [int(position.x), int(position.y)])
			else:
				_show_result("teleport: no player found")
		"help":
			_show_result("commands: god, mana, crit, hitbox, killall, xp n, points n, gear, save, load, reset_save, reload, export, fps, tp x y")
		_:
			_show_result("unknown command: %s (try 'help')" % tokens[0])

func _current_payload() -> Dictionary:
	var player: Node = DebugManager.find_player()
	if player == null or not player.has_method("capture_state"):
		return {}
	return player.capture_state()

func _refresh() -> void:
	var manager := DebugManager
	var stats: Dictionary = manager.frame_time_stats()
	var counts: Dictionary = manager.entity_counts()
	var player: Node2D = manager.find_player()
	var player_text := "—"
	var casting_text := ""
	var spawner_text := "—"
	var spawner: Node = manager.get_tree().root.get_node_or_null("SpawnManager")
	if spawner != null and spawner.has_method("stats"):
		var spawn_stats: Dictionary = spawner.stats()
		spawner_text = "active %d | pooled %d | created %d | reused %d" % [
			spawn_stats.get("active", 0), spawn_stats.get("pooled", 0),
			spawn_stats.get("created", 0), spawn_stats.get("reused", 0),
		]
	var loot_text := "—"
	var loot: Node = manager.get_tree().root.get_node_or_null("LootManager")
	if loot != null and loot.has_method("stats"):
		var loot_stats: Dictionary = loot.stats()
		loot_text = "drops %d | pooled %d | collected %d" % [
			loot_stats.get("active", 0), loot_stats.get("pooled", 0), loot_stats.get("collected", 0),
		]
	if player != null:
		player_text = "(%.0f, %.0f) | %s" % [player.global_position.x, player.global_position.y, _vitals_text(player)]
		if player.has_method("is_casting") and player.is_casting():
			casting_text = "casting %s %d%%" % [
				player.current_ability().id, int(player.cast_progress() * 100.0),
			]
	var memory_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	_stats_label.text = "\n".join([
		"FPS %d | frame %.2f ms (avg %.2f / min %.2f / max %.2f)" % [
			Engine.get_frames_per_second(), manager.frame_time_ms(), stats.avg, stats.min, stats.max,
		],
		"mem %.1f MB | objects %d | orphans %d" % [
			memory_mb,
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		],
		"scene %s" % manager.current_scene_path(),
		"player %s | enemies %d | projectiles %d | effects %d" % [
			player_text, counts.enemies, counts.projectiles, counts.effects,
		],
		"spawner %s" % spawner_text,
		"loot %s" % loot_text,
		"debug %s | F3 overlay | F1 god | F2 kill | F5 reload | F8 export" % (
			"ON" if manager.is_enabled() else "OFF"
		),
	] + ([casting_text] if casting_text != "" else []))
	_flags_label.text = "GOD %s | mana %s | crit %s | hitbox %s | AI %s" % [
		_on_off(manager.god_mode), _on_off(manager.infinite_mana),
		_on_off(manager.force_crit), _on_off(manager.show_hitboxes), _on_off(manager.disable_ai),
	]
	var counters: Dictionary = manager.counters
	_counters_label.text = "dmg dealt %.0f | taken %.0f | crit %d | kills %d | casts %d | deaths %d" % [
		counters.damage_dealt, counters.damage_taken, counters.crits,
		counters.kills, counters.casts, counters.deaths,
	]

func _show_result(text: String) -> void:
	_result_label.text = "> %s" % text

func _on_off(value: bool) -> String:
	return "ON" if value else "off"

func _vitals_text(player: Node2D) -> String:
	var hp = player.get("hp")
	var max_hp = player.get("max_hp")
	var mana = player.get("mana")
	var max_mana = player.get("max_mana")
	var parts: Array = []
	if hp != null and max_hp != null:
		parts.append("HP %.0f/%.0f" % [hp, max_hp])
	if mana != null and max_mana != null:
		parts.append("MP %.0f/%.0f" % [mana, max_mana])
	if player.has_method("get_inventory"):
		parts.append("gold %d" % player.get_inventory().currency)
	if player.has_method("level_progress"):
		parts.append("Lv %d %d%%" % [player.get("level"), int(player.call("level_progress") * 100.0)])
	if player.has_method("get_inventory"):
		parts.append("SP %d" % player.get("skill_points"))
	if player.has_method("equipment_power"):
		parts.append("PWR %d" % player.equipment_power())
	return " | ".join(parts)

func _ignore_mouse_on_containers() -> void:
	_set_mouse_filter_recursive(self)

func _set_mouse_filter_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if not (child is Button or child is LineEdit):
			if child is Control:
				(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_mouse_filter_recursive(child)
