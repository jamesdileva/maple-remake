class_name NPC
extends Node2D

signal talked(npc_id: StringName)

@export var npc_id := &"maren"
@export var display_name := "Villager Maren"
@export var dialogue_line := "Slimes ate our festival garlands. Your arcs can wipe the whole field at once. East gate leads deeper."
@export var talk_radius := 110.0

var _label: Label
var _player_in_range := false

func _ready() -> void:
	add_to_group("npcs")
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	_label.add_theme_color_override("font_outline_color", Color(0.12, 0.1, 0.14))
	_label.add_theme_constant_override("outline_size", 6)
	_label.position = Vector2(-160.0, -78.0)
	_label.custom_minimum_size = Vector2(320.0, 0.0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.z_index = 50
	_label.visible = false
	_label.text = "%s: %s" % [display_name, dialogue_line]
	add_child(_label)

func is_talking_to(player: Node) -> bool:
	return _player_in_range and player != null and is_instance_valid(player)

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	_player_in_range = player != null and is_instance_valid(player) \
		and global_position.distance_to((player as Node2D).global_position) <= talk_radius
	_label.visible = _player_in_range
	if _player_in_range and Input.is_action_just_pressed("interact"):
		talked.emit(npc_id)
		DebugManager.register_combat_event("npc_talked", {"npc": npc_id})
