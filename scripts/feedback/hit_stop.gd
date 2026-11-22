class_name HitStop
extends RefCounted

## Micro time-freeze on meaningful hits. Triggered from the damage
## pipeline; recovers on an unscaled timer so real-time length holds
## regardless of the game's time_scale.

static var enabled := true
static var _active := false

const DURATION := 0.05
const SCALE := 0.1

static func trigger(duration: float = DURATION, scale: float = SCALE) -> void:
	if not enabled or _active:
		return
	_active = true
	var previous := Engine.time_scale
	Engine.time_scale = scale
	var tree := Engine.get_main_loop() as SceneTree
	tree.create_timer(duration, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = previous
		_active = false)
