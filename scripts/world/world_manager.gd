extends Node

signal map_changed(map_id: StringName)

const MAPS_DIR := "res://data/maps/"
const TRAVEL_GRACE := 0.5

var starting_map_id := &"test_a"
var current_map_id := &""

var _registry := {}
var _travel_grace := 0.0

func _ready() -> void:
	scan_maps()

func _physics_process(delta: float) -> void:
	_travel_grace = maxf(0.0, _travel_grace - delta)

func scan_maps() -> int:
	var found := 0
	var directory := DirAccess.open(MAPS_DIR)
	if directory == null:
		return 0
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var definition := load(MAPS_DIR + file_name) as MapDefinition
		if definition == null or definition.scene == null:
			continue
		register_map(definition)
		found += 1
	return found

func register_map(definition: MapDefinition) -> void:
	if definition == null:
		return
	_registry[definition.id] = definition

func is_registered(map_id: StringName) -> bool:
	return _registry.has(map_id)

func boot() -> bool:
	return travel_to(starting_map_id, "")

func request_travel(map_id: StringName, spawn_tag: StringName) -> bool:
	if _travel_grace > 0.0:
		return false
	return travel_to(map_id, spawn_tag)

func travel_to(map_id: StringName, spawn_tag: StringName) -> bool:
	if not _registry.has(map_id):
		return false
	var host := _world_host()
	if host == null:
		return false
	var definition: MapDefinition = _registry[map_id]
	_clear_transients()
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	var map_root: Node2D = definition.scene.instantiate()
	host.add_child(map_root)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		var spawn := _find_spawn(map_root, spawn_tag, definition.default_spawn_tag)
		player.global_position = spawn.global_position if spawn != null else Vector2.ZERO
		player.velocity = Vector2.ZERO
	current_map_id = map_id
	_travel_grace = TRAVEL_GRACE
	map_changed.emit(map_id)
	DebugManager.register_combat_event("map_travel", {"map": map_id})
	return true

func _world_host() -> Node:
	var game := get_tree().root.get_node_or_null("Game/World")
	if game != null:
		return game
	var current := get_tree().current_scene
	if current != null:
		return current.get_node_or_null("World")
	return null

func _find_spawn(map_root: Node, spawn_tag: StringName, fallback_tag: StringName) -> MapSpawn:
	var first: MapSpawn = null
	for node in map_root.find_children("*", "MapSpawn", true, false):
		var spawn := node as MapSpawn
		if spawn == null:
			continue
		if first == null:
			first = spawn
		if spawn.spawn_tag == spawn_tag or (spawn_tag.is_empty() and spawn.spawn_tag == fallback_tag):
			return spawn
	return first

func _clear_transients() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.release_all_summons()
	var spawner: Node = get_tree().root.get_node_or_null("SpawnManager")
	if spawner != null and spawner.has_method("reset"):
		spawner.reset()
	var loot: Node = get_tree().root.get_node_or_null("LootManager")
	if loot != null and loot.has_method("reset"):
		loot.reset()
