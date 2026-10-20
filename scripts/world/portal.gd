class_name Portal
extends Area2D

@export var target_map_id := &"test_b"
@export var target_spawn_tag := &"default"
@export var retrigger_delay := 0.5
@export var show_hint := true
@export var hint_radius := 140.0

var _cooldown := 0.0
var _hint: Label

func _ready() -> void:
	collision_layer = 0
	collision_mask = CollisionLayers.WORLD
	monitoring = true
	add_to_group("portals")
	if show_hint:
		_build_hint()

func hint_text() -> String:
	var definition := _target_definition()
	if definition == null:
		return "-> %s" % String(target_map_id)
	return "-> %s  Lv %d" % [definition.display_name, definition.recommended_level]

func _target_definition() -> MapDefinition:
	if is_inside_tree():
		var manager := get_tree().root.get_node_or_null("WorldManager")
		if manager != null:
			var registered: MapDefinition = manager.get_definition(target_map_id)
			if registered != null:
				return registered
	var path := "res://data/maps/%s.tres" % String(target_map_id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MapDefinition

func _build_hint() -> void:
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.16))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.position = Vector2(-110.0, -62.0)
	_hint.custom_minimum_size = Vector2(220.0, 0.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.z_index = 45
	_hint.text = hint_text()
	_hint.visible = false
	add_child(_hint)

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if _hint != null:
		_hint.visible = global_position.distance_to(
			(player as Node2D).global_position) <= hint_radius
	if _cooldown > 0.0:
		return
	if not _overlaps(player):
		return
	_cooldown = retrigger_delay
	WorldManager.request_travel(target_map_id, target_spawn_tag)

func _overlaps(player: Node) -> bool:
	for body: Node in get_overlapping_bodies():
		if body == player:
			return true
	return false
