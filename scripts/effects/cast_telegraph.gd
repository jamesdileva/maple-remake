class_name CastTelegraph
extends Node2D

const BASE_SIZE := Vector2(52.0, 24.0)

@export var pulse_speed := 14.0
@export var pulse_amount := 0.12

var base_scale := Vector2.ONE
var _elapsed := 0.0

func _ready() -> void:
	base_scale = scale

func _process(delta: float) -> void:
	_elapsed += delta
	var pulse := 1.0 + sin(_elapsed * pulse_speed) * pulse_amount
	scale = base_scale * pulse
