extends Node

const PICKUP_SCENE_PATH := "res://scenes/loot/loot_pickup.tscn"
const FLASH_SCENE_PATH := "res://scenes/effects/pickup_flash.tscn"

@export var enabled := true
@export var max_active_pickups := 240

var _active: Array = []
var _free: Array = []
var _spawned_total := 0
var _collected_total := 0

func _ready() -> void:
	EventBus.mob_died_at.connect(_on_mob_died)

func active_pickup_count() -> int:
	var count := 0
	for pickup in _active:
		if is_instance_valid(pickup):
			count += 1
	return count

func stats() -> Dictionary:
	return {
		"active": active_pickup_count(),
		"pooled": _free.size(),
		"spawned": _spawned_total,
		"collected": _collected_total,
	}

func reset() -> void:
	for pickup in _active:
		if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
			pickup.queue_free()
	_active.clear()
	_free.clear()
	_spawned_total = 0
	_collected_total = 0

func spawn_drops(definition: MobDefinition, position: Vector2, parent: Node) -> int:
	if not enabled or definition == null or definition.loot_table == null:
		return 0
	var spawned := 0
	for drop: Dictionary in definition.loot_table.roll():
		var item: ItemDefinition = drop.get("item")
		var amount: int = drop.get("amount", 0)
		if item == null or amount <= 0:
			continue
		if active_pickup_count() >= max_active_pickups:
			DebugManager.register_combat_event("loot_cap_reached", {
				"cap": max_active_pickups,
				"active": active_pickup_count(),
			})
			break
		var pickup := _acquire(parent)
		if pickup == null:
			break
		pickup.setup(item, amount, 0.12)
		pickup.global_position = position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 0.0))
		spawned += 1
	return spawned

func collect_pickup(pickup: LootPickup) -> void:
	if not is_instance_valid(pickup):
		return
	var player := _find_player()
	var accepted := 0
	if player != null and player.has_method("receive_loot"):
		accepted = player.receive_loot(pickup.item, pickup.amount)
	if accepted > 0:
		_collected_total += 1
		_spawn_flash(pickup.global_position)
		DebugManager.register_combat_event("loot_collected", {
			"item": pickup.item.id if pickup.item != null else &"",
			"amount": accepted,
		})
		EventBus.loot_collected.emit(pickup.item.id if pickup.item != null else &"", accepted)
	_release(pickup)

func expire_pickup(pickup: LootPickup) -> void:
	_release(pickup)

func _on_mob_died(_mob_id: StringName, _xp: float, definition: Resource, position: Vector2) -> void:
	if not enabled or not (definition is MobDefinition):
		return
	var mob_definition := definition as MobDefinition
	var parent := _world_root(mob_definition)
	if parent != null:
		spawn_drops(mob_definition, position, parent)

func _acquire(parent: Node) -> LootPickup:
	var scene: PackedScene = load(PICKUP_SCENE_PATH)
	if scene == null:
		return null
	var pickup: LootPickup = null
	while not _free.is_empty():
		var candidate = _free.pop_back()
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			pickup = candidate
			break
	if pickup == null:
		pickup = scene.instantiate()
	else:
		pickup.visible = true
		pickup.process_mode = Node.PROCESS_MODE_INHERIT
	_pickup_parent(pickup, parent)
	pickup.pool_owner = self
	_spawned_total += 1
	_active.append(pickup)
	return pickup

func _release(pickup: LootPickup) -> void:
	if pickup == null:
		return
	_active.erase(pickup)
	if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
		pickup.visible = false
		pickup.process_mode = Node.PROCESS_MODE_DISABLED
		_free.append(pickup)
	else:
		_active.erase(pickup)

func _pickup_parent(pickup: LootPickup, parent: Node) -> void:
	if parent == null:
		return
	if pickup.get_parent() != null:
		pickup.get_parent().remove_child(pickup)
	parent.add_child(pickup)

func _spawn_flash(position: Vector2) -> void:
	var scene: PackedScene = load(FLASH_SCENE_PATH)
	if scene == null:
		return
	var flash: Node2D = scene.instantiate()
	flash.add_to_group("effects")
	var world := _current_world()
	if world == null:
		flash.queue_free()
		return
	world.add_child(flash)
	flash.global_position = position

func _current_world() -> Node:
	var player := _find_player()
	if player == null:
		return null
	return player.get_parent()

func _world_root(definition: MobDefinition) -> Node:
	var world := _current_world()
	return world

func _find_player() -> Node2D:
	var player: Node = get_tree().get_first_node_in_group("player")
	return player as Node2D
