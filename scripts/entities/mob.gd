class_name Mob
extends CharacterBody2D

const CONTACT_REACH_X := 34.0
const CONTACT_REACH_Y := 44.0
const BOB_AMPLITUDE := 2.5
const BOB_SPEED := 5.0

@export var definition: MobDefinition

var hp := 0.0
var dead := false
var chain_depth := 0

var pool_owner: Object
var _pool_tracked := false

var _contact_cooldown := 0.0
var _slow_remaining := 0.0
var _slow_factor := 1.0
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
	_slow_remaining = maxf(0.0, _slow_remaining - delta)
	velocity.y += _gravity * delta
	var player := _find_player()
	var speed_scale := _speed_scale()
	if DebugManager.disable_ai:
		velocity.x = 0.0
	elif player == null:
		velocity.x = move_toward(velocity.x, 0.0, _move_speed * delta * 4.0)
	else:
		velocity.x = signf(player.global_position.x - global_position.x) * (_move_speed * speed_scale)
	move_and_slide()
	_animate_visual(delta)
	_try_contact_damage(player)

func apply_slow(duration: float, factor: float) -> void:
	if duration <= 0.0:
		return
	_slow_remaining = maxf(_slow_remaining, duration)
	_slow_factor = clampf(1.0 - factor, 0.05, 1.0)

func _speed_scale() -> float:
	return _slow_factor if _slow_remaining > 0.0 else 1.0

func is_slowed() -> bool:
	return _slow_remaining > 0.0

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
	EventBus.mob_died_at.emit(mob_id(), xp_reward(), definition, global_position)
	_spawn_chain_children()
	_spawn_explosion()
	_return_to_pool()

func _return_to_pool() -> void:
	if pool_owner != null and pool_owner.has_method("queue_recycle"):
		enter_pool()
		pool_owner.queue_recycle(self)
		return
	if _pool_tracked:
		var spawner := _chain_spawner()
		if spawner != null and spawner.has_method("release_orphan_mob"):
			enter_pool()
			spawner.release_orphan_mob(self)
			return
	queue_free()

func _spawn_chain_children() -> void:
	if definition == null or definition.chain == null:
		return
	if chain_depth >= definition.max_chain_depth:
		return
	var payload: ChainPayload = definition.chain
	if payload.child_definition == null or payload.child_count <= 0:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	for index in range(payload.child_count):
		var angle: float = TAU * float(index) / float(payload.child_count)
		var offset: Vector2 = Vector2(cos(angle), sin(angle) * 0.35) * payload.spawn_radius
		var spawner = _chain_spawner()
		if spawner == null:
			return
		var child: Mob = spawner.acquire_chain_child(payload.child_definition, global_position + offset, parent_node)
		if child == null:
			continue
		child.chain_depth = chain_depth + 1

func _chain_spawner() -> Node:
	var spawner: Node = get_tree().root.get_node_or_null("SpawnManager")
	if spawner != null and spawner.has_method("acquire_chain_child"):
		return spawner
	return null

func _spawn_explosion() -> void:
	if definition == null or definition.chain == null:
		return
	var explosion: Node2D = load("res://scenes/effects/chain_explosion.tscn").instantiate()
	explosion.add_to_group("effects")
	var parent_node := get_parent()
	if parent_node == null:
		explosion.queue_free()
		return
	parent_node.add_child(explosion)
	explosion.global_position = global_position

func enter_pool() -> void:
	dead = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	remove_from_group("enemies")

func set_pool_tracked(tracked: bool) -> void:
	_pool_tracked = tracked

func exit_pool(mob_definition: MobDefinition, spawn_position: Vector2) -> void:
	definition = mob_definition
	hp = mob_definition.max_hp
	dead = false
	chain_depth = 0
	global_position = spawn_position
	velocity = Vector2.ZERO
	_contact_cooldown = 0.0
	_bob_time = 0.0
	_gravity = mob_definition.gravity
	_move_speed = mob_definition.move_speed
	_contact_damage = mob_definition.contact_damage
	_contact_interval = mob_definition.contact_interval
	_xp = mob_definition.xp
	collision_layer = CollisionLayers.MOBS
	collision_mask = CollisionLayers.WORLD
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	add_to_group("enemies")
	_pool_tracked = true

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
