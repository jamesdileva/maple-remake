class_name Summon
extends Node2D

const FOLLOW_DISTANCE := 70.0
const ATTACK_RANGE := 130.0
const REACH := 34.0

@export var attack_interval := 1.0
@export var damage := 8.0
@export var duration := 12.0
@export var follow_speed := 260.0

var pool_owner: Object

var _lifetime := 0.0
var _cooldown := 0.0
var _player: Node2D
var _visual: ColorRect

func _ready() -> void:
	add_to_group("allies")
	_visual = get_node_or_null("Body") as ColorRect

func _physics_process(delta: float) -> void:
	_lifetime += delta
	if duration > 0.0 and _lifetime >= duration:
		_expire()
		return
	var player := _find_player()
	if player == null:
		return
	_position_near_player(player, delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown <= 0.0:
		_attack(player)

func _position_near_player(player: Node2D, delta: float) -> void:
	var offset: Vector2 = player.global_position - global_position
	if offset.length() < FOLLOW_DISTANCE:
		return
	global_position += offset.normalized() * minf(offset.length(), follow_speed * delta)

func _attack(player: Node2D) -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	if target.global_position.distance_to(global_position) > ATTACK_RANGE:
		return
	_cooldown = attack_interval
	target.take_damage(damage, player)

func _nearest_enemy() -> Object:
	var best: Object = null
	var best_distance := INF
	for candidate: Object in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate):
			continue
		if not (candidate is Mob):
			continue
		if candidate.is_dead():
			continue
		var distance: float = candidate.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _expire() -> void:
	if pool_owner != null and pool_owner.has_method("release_summon"):
		pool_owner.release_summon(self)
	else:
		queue_free()

func _find_player() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	var player: Node = get_tree().get_first_node_in_group("player")
	_player = player as Node2D
	return _player
