class_name ChainExplosion
extends Node2D

const EXPAND_TIME := 0.3

@export var start_radius := 10.0
@export var end_radius := 42.0

var _elapsed := 0.0

func _ready() -> void:
	modulate = Color(1, 1, 1, 0)

func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = minf(1.0, _elapsed / EXPAND_TIME if EXPAND_TIME > 0.0 else 1.0)
	var radius: float = lerpf(start_radius, end_radius, progress)
	$Ring.scale = Vector2(radius / Ring.BASE_RADIUS, radius / Ring.BASE_RADIUS)
	modulate.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()
