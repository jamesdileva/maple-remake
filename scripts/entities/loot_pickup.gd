class_name LootPickup
extends Node2D

const POP_IN_TIME := 0.1

@export var collect_radius := 26.0
@export var vacuum_speed := 520.0
@export var vacuum_accel := 2600.0
@export var spawn_delay := 0.12
@export var max_lifetime := 8.0

var item: ItemDefinition
var amount := 1
var pool_owner: Object

var _delay := 0.0
var _age := 0.0
var _speed := 0.0
var _visual: ColorRect
var _player: Node2D

func _ready() -> void:
	_visual = get_node_or_null("Visual") as ColorRect
	scale = Vector2.ZERO

func setup(item_definition: ItemDefinition, count: int, delay: float) -> void:
	item = item_definition
	amount = count
	_delay = delay
	_age = 0.0
	_speed = 0.0
	scale = Vector2.ZERO
	if _visual != null:
		_visual.color = item.tint if item != null else Color.WHITE

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= max_lifetime:
		_expire()
		return
	_pop_in(delta)
	if _delay > 0.0:
		_delay = maxf(0.0, _delay - delta)
		return
	var player := _find_player()
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() <= collect_radius:
		_collect()
		return
	_speed = minf(vacuum_speed, _speed + vacuum_accel * delta)
	global_position += to_player.normalized() * _speed * delta

func _pop_in(delta: float) -> void:
	if scale.length() >= 1.0:
		return
	scale = Vector2.ONE * minf(1.0, scale.x + delta / POP_IN_TIME)

func _collect() -> void:
	if pool_owner != null and pool_owner.has_method("collect_pickup"):
		pool_owner.collect_pickup(self)

func _expire() -> void:
	if pool_owner != null and pool_owner.has_method("expire_pickup"):
		pool_owner.expire_pickup(self)

func _find_player() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	if get_tree() == null:
		return null
	var player: Node = get_tree().get_first_node_in_group("player")
	_player = player as Node2D
	return _player
