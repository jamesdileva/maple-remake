extends Node

const MAX_RECYCLES_PER_FRAME := 32

@export var enabled := true
@export var max_active_mobs := 250

var _pool: MobPool
var _zones: Array = []
var _recycle_queue: Array = []
var _spawned_total := 0

func _ready() -> void:
	_pool_ref()

func _pool_ref() -> MobPool:
	if _pool == null:
		var container := Node2D.new()
		container.name = "MobPoolRoot"
		add_child(container)
		_pool = MobPool.new(container)
	return _pool

func register_zone(zone: SpawnZone) -> void:
	if zone == null or _zones.has(zone):
		return
	_zones.append(zone)
	zone.tick(0.0)

func active_mob_count() -> int:
	_prune_zones()
	var total := 0
	for zone in _zones:
		total += zone.live_count()
	return total

func reset() -> void:
	_zones.clear()
	_recycle_queue.clear()
	_pool_ref().clear()
	_spawned_total = 0
	max_active_mobs = 250

func stats() -> Dictionary:
	var data := {"active": active_mob_count(), "zones": _zones.size(), "spawned": _spawned_total}
	data.merge(_pool_ref().stats())
	return data

func spawn_zone(zone: SpawnZone) -> int:
	if zone == null or not enabled:
		return 0
	var spawned := 0
	while zone.wants_spawn() and active_mob_count() < max_active_mobs:
		var position: Vector2 = zone.random_point()
		var mob: Mob = _pool_ref().acquire(zone.definition, position, zone.get_parent())
		if mob == null:
			break
		mob.pool_owner = self
		zone.track(mob)
		_spawned_total += 1
		spawned += 1
		zone.tick(0.0)
	return spawned

func queue_recycle(mob: Mob) -> void:
	if mob != null and not _recycle_queue.has(mob):
		_recycle_queue.append(mob)

func _physics_process(delta: float) -> void:
	_prune_zones()
	if enabled:
		for zone in _zones:
			zone.tick(delta)
			if zone.wants_spawn():
				spawn_zone(zone)
	_flush_recycle_queue()

func _prune_zones() -> void:
	_zones = _zones.filter(func(zone) -> bool: return is_instance_valid(zone))

func _flush_recycle_queue() -> void:
	var budget := MAX_RECYCLES_PER_FRAME
	while budget > 0 and not _recycle_queue.is_empty():
		var mob = _recycle_queue.pop_front()
		budget -= 1
		if not is_instance_valid(mob) or mob.is_queued_for_deletion():
			continue
		for zone in _zones:
			if zone.mobs.has(mob):
				zone.untrack(mob)
				break
		_pool_ref().release(mob)
