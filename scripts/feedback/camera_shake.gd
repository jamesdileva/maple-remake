class_name CameraShake
extends Camera2D

## Decaying random camera offset. The player's camera runs this script;
## damage taken and heavy casts kick it.

static var kick_enabled := true

const DECAY := 9.0

var _shake := 0.0

func kick(strength: float) -> void:
	if not kick_enabled:
		return
	_shake = minf(10.0, _shake + strength)

func _physics_process(delta: float) -> void:
	print("cam dbg: process tick shake=", _shake)
	if _shake <= 0.0:
		offset = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - DECAY * delta)
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
