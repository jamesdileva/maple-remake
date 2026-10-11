class_name SpawnZone
extends Node2D

@export var zone_rect: Rect2 = Rect2(-100.0, -60.0, 200.0, 120.0)
@export var definition: MobDefinition
@export var capacity := 12
@export var respawn_delay := 1.5

var mobs: Array = []

var _respawn_timer := 0.0

func _ready() -> void:
	if is_inside_tree() and Engine.is_editor_hint():
		return
	if SpawnManager != null:
		SpawnManager.register_zone(self)

func global_rect() -> Rect2:
	return Rect2(get_global_transform() * zone_rect.position, zone_rect.size)

func random_point() -> Vector2:
	var area := global_rect()
	return Vector2(
		randf_range(area.position.x, area.end.x),
		randf_range(area.position.y, area.end.y)
	)

func live_count() -> int:
	var alive := 0
	for mob in mobs:
		if is_instance_valid(mob) and not mob.is_dead():
			alive += 1
	return alive

func track(mob: Mob) -> void:
	if mob != null and not mobs.has(mob):
		mobs.append(mob)

func untrack(mob: Mob) -> void:
	mobs.erase(mob)

func tick(delta: float) -> void:
	if live_count() >= capacity:
		_respawn_timer = respawn_delay
		return
	_respawn_timer = maxf(0.0, _respawn_timer - delta)

func wants_spawn() -> bool:
	return live_count() < capacity and _respawn_timer <= 0.0
