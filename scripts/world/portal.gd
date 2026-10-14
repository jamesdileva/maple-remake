class_name Portal
extends Area2D

@export var target_map_id := &"test_b"
@export var target_spawn_tag := &"default"
@export var retrigger_delay := 0.5

var _cooldown := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = CollisionLayers.WORLD
	monitoring = true
	add_to_group("portals")

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if not _overlaps(player):
		return
	_cooldown = retrigger_delay
	WorldManager.request_travel(target_map_id, target_spawn_tag)

func _overlaps(player: Node) -> bool:
	for body: Node in get_overlapping_bodies():
		if body == player:
			return true
	return false
