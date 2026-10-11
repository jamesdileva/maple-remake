class_name MobPool
extends RefCounted

var _root: Node
var _free: Dictionary = {}
var _live: Array = []
var _pooled: Array = []
var _created := 0
var _reused := 0
var _released := 0

func _init(root: Node) -> void:
	_root = root

func acquire(mob_definition: MobDefinition, spawn_position: Vector2, parent: Node) -> Mob:
	if mob_definition == null or mob_definition.mob_scene == null:
		return null
	var mob := _pop_free(mob_definition.id)
	if mob == null:
		if _root == null:
			return null
		mob = mob_definition.mob_scene.instantiate()
		_root.add_child(mob)
		_created += 1
	_place(mob, parent)
	mob.exit_pool(mob_definition, spawn_position)
	_track_live(mob)
	return mob

func release(mob: Mob) -> void:
	if mob == null or not is_instance_valid(mob):
		return
	_untrack_live(mob)
	if not mob.is_queued_for_deletion():
		mob.enter_pool()
	var key: StringName = mob.mob_id()
	if not _free.has(key):
		_free[key] = []
	_free[key].append(mob)
	_released += 1
	_place(mob, _root)
	_track_pooled(mob)

func entity_count() -> int:
	var count := 0
	for mob in _live:
		if _is_usable(mob):
			count += 1
	for mob in _pooled:
		if _is_usable(mob):
			count += 1
	return count

func _is_usable(mob) -> bool:
	return is_instance_valid(mob) and not mob.is_queued_for_deletion()

func live_count() -> int:
	var alive := 0
	for mob in _live:
		if _is_usable(mob) and not mob.is_dead():
			alive += 1
	return alive

func world_root() -> Node:
	var world := _root.get_parent()
	if world == null or not (world is Node2D):
		return _root
	return world

func stats() -> Dictionary:
	var pooled_count := 0
	for key: StringName in _free:
		pooled_count += _free[key].size()
	return {
		"created": _created,
		"reused": _reused,
		"released": _released,
		"pooled": pooled_count,
	}

func clear() -> void:
	for key: StringName in _free:
		for mob in _free[key]:
			if is_instance_valid(mob) and not mob.is_queued_for_deletion():
				mob.queue_free()
	_free.clear()
	_live.clear()
	_pooled.clear()
	_created = 0
	_reused = 0
	_released = 0

func _pop_free(definition_id: StringName) -> Mob:
	var free_list: Array = _free.get(definition_id, [])
	while not free_list.is_empty():
		var pooled: Mob = free_list.pop_back()
		if is_instance_valid(pooled) and not pooled.is_queued_for_deletion():
			_untrack_pooled(pooled)
			_reused += 1
			return pooled
	return null

func _track_live(mob: Mob) -> void:
	if not _live.has(mob):
		_live.append(mob)

func _untrack_live(mob: Mob) -> void:
	_live.erase(mob)

func _track_pooled(mob: Mob) -> void:
	if not _pooled.has(mob):
		_pooled.append(mob)

func _untrack_pooled(mob: Mob) -> void:
	_pooled.erase(mob)

func _place(mob: Mob, parent: Node) -> void:
	if parent == null or mob.get_parent() == parent:
		return
	if mob.get_parent() != null:
		mob.get_parent().remove_child(mob)
	parent.add_child(mob)
