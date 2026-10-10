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
			_show_result("commands: god, mana, crit, hitbox, killall, reload, export, fps, tp x y")
		_:
			_show_result("unknown command: %s (try 'help')" % tokens[0])

func _refresh() -> void:
	var manager := DebugManager
	var stats: Dictionary = manager.frame_time_stats()
	var counts: Dictionary = manager.entity_counts()
	var player: Node2D = manager.find_player()
	var player_text := "—"
	if player != null:
		player_text = "(%.0f, %.0f)" % [player.global_position.x, player.global_position.y]
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
		"debug %s | F3 overlay | F1 god | F2 kill | F5 reload | F8 export" % (
			"ON" if manager.is_enabled() else "OFF"
		),
	])
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

func _ignore_mouse_on_containers() -> void:
	_set_mouse_filter_recursive(self)

func _set_mouse_filter_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if not (child is Button or child is LineEdit):
			if child is Control:
				(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_mouse_filter_recursive(child)
