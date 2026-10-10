class_name Mob
extends CharacterBody2D

const CONTACT_REACH_X := 34.0
const CONTACT_REACH_Y := 44.0
const BOB_AMPLITUDE := 2.5
const BOB_SPEED := 5.0

@export var definition: MobDefinition

var hp := 0.0
var dead := false

var _contact_cooldown := 0.0
var _gravity := 900.0
var _move_speed := 70.0
var _contact_damage := 5.0
var _contact_interval := 0.8
var _xp := 5.0
var _player: Node2D
var _visual: Node2D
var _bob_time := 0.0

func _ready() -> void:
	collision_layer = CollisionLayers.MOBS
	collision_mask = CollisionLayers.WORLD
	if definition != null:
		hp = definition.max_hp
		_gravity = definition.gravity
		_move_speed = definition.move_speed
		_contact_damage = definition.contact_damage
		_contact_interval = definition.contact_interval
		_xp = definition.xp
	_visual = get_node_or_null("Visual") as Node2D
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if dead:
		return
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	velocity.y += _gravity * delta
	var player := _find_player()
	if DebugManager.disable_ai:
		velocity.x = 0.0
	elif player == null:
		velocity.x = move_toward(velocity.x, 0.0, _move_speed * delta * 4.0)
	else:
		velocity.x = signf(player.global_position.x - global_position.x) * _move_speed
	move_and_slide()
	_animate_visual(delta)
	_try_contact_damage(player)

func take_damage(amount: float, source: Node = null) -> float:
	return DamageSystem.apply(DamageEvent.create(self, amount, source)).applied

func apply_damage(amount: float) -> float:
	hp -= amount
	return hp

func is_dead() -> bool:
	return dead

func die(_event: DamageEvent) -> void:
	if dead:
		return
	dead = true
	DebugManager.register_combat_event("kill", {"mob": mob_id()})
	EventBus.mob_died.emit(mob_id(), xp_reward(), definition)
	queue_free()

func apply_debug_kill() -> void:
	take_damage(999999.0, null)

func get_defense() -> float:
	return definition.defense if definition != null else 0.0

func get_crit_chance() -> float:
	return 0.0

func mob_id() -> StringName:
	return definition.id if definition != null else &"mob"

func xp_reward() -> float:
	return _xp

func _animate_visual(delta: float) -> void:
	_bob_time += delta
	if _visual != null:
		_visual.position.y = sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE

func _try_contact_damage(player: Node2D) -> void:
	if player == null or _contact_cooldown > 0.0:
		return
	if not _touching(player):
		return
	_contact_cooldown = _contact_interval
	if player.has_method("take_damage"):
		player.take_damage(_contact_damage, self)

func _touching(player: Node2D) -> bool:
	for index in range(get_slide_collision_count()):
		if get_slide_collision(index).get_collider() == player:
			return true
	return absf(player.global_position.x - global_position.x) < CONTACT_REACH_X \
		and absf(player.global_position.y - global_position.y) < CONTACT_REACH_Y

func _find_player() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	if get_tree() == null:
		return null
	var player: Node = get_tree().get_first_node_in_group("player")
	_player = player as Node2D
	return _player
