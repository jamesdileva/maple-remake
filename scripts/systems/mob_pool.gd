class_name MobPool
extends RefCounted

var _root: Node
var _free: Dictionary = {}
var _created := 0
var _reused := 0
var _released := 0

func _init(root: Node) -> void:
	_root = root

func acquire(mob_definition: MobDefinition, spawn_position: Vector2, parent: Node) -> Mob:
	if mob_definition == null or mob_definition.mob_scene == null:
		return null
	var free_list: Array = _free.get(mob_definition.id, [])
	while not free_list.is_empty():
		var pooled: Mob = free_list.pop_back()
		if is_instance_valid(pooled) and not pooled.is_queued_for_deletion():
			_reused += 1
			_reparent(pooled, parent)
			pooled.exit_pool(mob_definition, spawn_position)
			return pooled
	if _root == null:
		return null
	var mob: Mob = mob_definition.mob_scene.instantiate()
	_root.add_child(mob)
	_created += 1
	_reparent(mob, parent)
	mob.exit_pool(mob_definition, spawn_position)
	return mob

func release(mob: Mob) -> void:
	if mob == null or not is_instance_valid(mob):
		return
	var key: StringName = mob.mob_id()
	if not _free.has(key):
		_free[key] = []
	_free[key].append(mob)
	_released += 1
	_reparent(mob, _root)

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
	_created = 0
	_reused = 0
	_released = 0

func _reparent(mob: Mob, parent: Node) -> void:
	if parent == null or mob.get_parent() == parent:
		return
	if mob.get_parent() != null:
		mob.get_parent().remove_child(mob)
	parent.add_child(mob)
