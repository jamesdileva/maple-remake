class_name DamageNumber
extends Label

## Floating combat text: rises off the target and fades. Spawned from
## the damage pipeline for every applied hit.

static var enabled := true

const LIFETIME := 0.5
const RISE := 26.0
const COLOR_HIT := Color(0.95, 0.9, 0.75, 1)
const COLOR_CRIT := Color(1.0, 0.75, 0.3, 1)
const COLOR_PLAYER := Color(1.0, 0.35, 0.3, 1)

var _remaining := LIFETIME
var _origin := Vector2.ZERO

static func spawn(parent: Node, position: Vector2, amount: float, kind: int) -> void:
	if not enabled or parent == null or amount <= 0.0:
		return
	var label := DamageNumber.new()
	label.text = str(int(round(amount)))
	label.add_theme_font_size_override("font_size", 15 if kind == KIND_DEALT else 13)
	label.add_theme_color_override("font_color", COLOR_CRIT if kind == KIND_CRIT else COLOR_HIT)
	if kind == KIND_PLAYER:
		label.add_theme_color_override("font_color", COLOR_PLAYER)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12, 1))
	label.z_index = 60
	label.add_to_group("effects")
	label.add_to_group("damage_numbers")
	label._origin = position + Vector2(randf_range(-9.0, 9.0), -16.0)
	label.position = label._origin
	parent.add_child(label)

enum { KIND_DEALT, KIND_CRIT, KIND_PLAYER }

func _ready() -> void:
	custom_minimum_size = Vector2(40, 18)
	size = Vector2(40, 18)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _physics_process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	var progress := 1.0 - (_remaining / LIFETIME)
	position.y = _origin.y - RISE * progress
	modulate.a = 1.0 - progress
	if _remaining == 0.0:
		queue_free()
