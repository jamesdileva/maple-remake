class_name ImpactBurst
extends Node2D

var lifetime := 0.25

var _remaining := 0.0

func _ready() -> void:
	_remaining = lifetime

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	var progress := 1.0 - (_remaining / lifetime if lifetime > 0.0 else 0.0)
	modulate.a = 1.0 - progress
	scale = Vector2.ONE * (1.0 + progress)
	if _remaining == 0.0:
		queue_free()
