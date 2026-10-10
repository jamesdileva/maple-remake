class_name FmaBurst
extends Node2D

const EXPAND_TIME := 0.35

@export var fill_color := Color(1.0, 0.72, 0.32, 0.4)

var _elapsed := 0.0

func _ready() -> void:
	modulate = Color(1.0, 1.0, 1.0, 0.0)

func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = minf(1.0, _elapsed / EXPAND_TIME if EXPAND_TIME > 0.0 else 1.0)
	modulate.a = fill_color.a * (1.0 - progress)
	scale = Vector2.ONE * (0.35 + 0.65 * progress)
	if progress >= 1.0:
		queue_free()
