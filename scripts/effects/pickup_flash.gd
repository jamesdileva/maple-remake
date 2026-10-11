class_name PickupFlash
extends Node2D

const FADE_TIME := 0.22

@export var radius := 18.0

var _elapsed := 0.0

func _ready() -> void:
	modulate = Color(1, 1, 1, 0)

func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = minf(1.0, _elapsed / FADE_TIME if FADE_TIME > 0.0 else 1.0)
	modulate.a = 1.0 - progress
	scale = Vector2.ONE * (1.0 + progress)
	if progress >= 1.0:
		queue_free()
