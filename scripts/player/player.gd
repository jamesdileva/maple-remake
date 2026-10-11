class_name Player
extends CharacterBody2D

signal state_changed(new_state: StringName)

enum State { IDLE, RUN, JUMP, FALL }

@export var run_speed := 280.0
@export var ground_acceleration := 2400.0
@export var ground_deceleration := 2600.0
@export var air_acceleration := 1800.0
@export var air_deceleration := 400.0
@export var jump_velocity := 640.0
@export var gravity := 1900.0
@export var rise_gravity_multiplier := 0.55
@export var fall_gravity_multiplier := 1.35
@export var jump_cut_multiplier := 2.2
@export var coyote_time := 0.09
@export var jump_buffer_time := 0.1
@export var visual_path: NodePath = NodePath("Visual")
@export var attack_hitbox_path: NodePath = NodePath("AttackHitbox")

@export var max_hp := 100.0
@export var hp := 100.0
@export var max_mana := 100.0
@export var mana := 100.0
@export var mana_regen_per_second := 8.0
@export var defense := 0.0
@export var crit_chance := 0.05
@export var crit_multiplier := 2.0
@export var basic_attack_damage := 12.0
@export var basic_attack_cooldown := 0.35
@export var basic_attack_duration := 0.12
@export var basic_attack_range := 52.0
@export var ability_slots: Array[AbilityDefinition] = []

var inventory := Inventory.new()

signal died
signal attack_started
signal cast_started(ability: AbilityDefinition)
signal cast_completed(ability: AbilityDefinition, targets_hit: int)

const ABILITY_SLOT_COUNT := 4

var state: State = State.IDLE:
	set(value):
		if value == state:
			return
		state = value
		state_changed.emit(_state_name(value))

var move_direction := 0.0
var facing := 1

var _coyote := 0.0
var _jump_buffer := 0.0
var _attack_timer := 0.0
var _attack_active := 0.0
var _attack_hit_targets: Array = []
var _visual: Node2D
var _attack_hitbox: Area2D
var _cast_timer := 0.0
var _cast_ability: AbilityDefinition
var _cast_telegraph: Node2D

func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node2D
	_attack_hitbox = get_node_or_null(attack_hitbox_path) as Area2D
	if _attack_hitbox != null:
		_attack_hitbox.monitoring = false
	add_to_group("player")

func is_casting() -> bool:
	return _cast_timer > 0.0

func cast_progress() -> float:
	if _cast_ability == null or _cast_ability.cast_time <= 0.0:
		return 0.0
	return 1.0 - (_cast_timer / _cast_ability.cast_time)

func current_ability() -> AbilityDefinition:
	return _cast_ability

func ability_at(slot: int) -> AbilityDefinition:
	if slot < 0 or slot >= ability_slots.size():
		return null
	return ability_slots[slot]

func take_damage(amount: float, source: Node = null) -> float:
	if DebugManager.is_invulnerable():
		return 0.0
	return DamageSystem.apply(DamageEvent.create(self, amount, source)).applied

func apply_damage(amount: float) -> float:
	hp -= amount
	return hp

func is_dead() -> bool:
	return hp <= 0.0

func die(_event: DamageEvent) -> void:
	DebugManager.register_combat_event("death", {})
	EventBus.player_died.emit()
	died.emit()
	hp = max_hp
	global_position = Vector2(0.0, -60.0)
	velocity = Vector2.ZERO

func get_defense() -> float:
	return defense

func get_crit_chance() -> float:
	return crit_chance

func get_crit_multiplier() -> float:
	return crit_multiplier

func apply_debug_kill() -> void:
	take_damage(999999.0, null)

func heal_full() -> void:
	hp = max_hp

func get_inventory() -> Inventory:
	return inventory

func receive_loot(item: ItemDefinition, count: int) -> int:
	if item == null or count <= 0:
		return 0
	if item.is_currency():
		return inventory.add_currency(item.value * count)
	return inventory.add_item(item, count)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_tick_attack(delta)
	_tick_cast(delta)
	_regenerate_mana(delta)
	move_direction = Input.get_axis("move_left", "move_right")
	_update_facing()
	_apply_horizontal(delta)
	_apply_gravity(delta)
	_apply_jump()
	if _casting_locked():
		velocity.x = 0.0
	move_and_slide()
	_update_state()

func _casting_locked() -> bool:
	return _cast_timer > 0.0

func _regenerate_mana(delta: float) -> void:
	if DebugManager.infinite_mana or mana >= max_mana:
		return
	mana = minf(max_mana, mana + mana_regen_per_second * delta)

func _tick_cast(delta: float) -> void:
	if _cast_timer > 0.0:
		_cast_timer = maxf(0.0, _cast_timer - delta)
		if _cast_timer == 0.0:
			_finish_cast()
		return
	for slot in ABILITY_SLOT_COUNT:
		if Input.is_action_just_pressed("skill_%d" % (slot + 1)):
			_try_cast_ability(slot)
			return

func _try_cast_ability(slot: int) -> void:
	var ability := ability_at(slot)
	if ability == null:
		return
	if not DebugManager.infinite_mana and ability.mana_cost > 0.0:
		if mana < ability.mana_cost:
			return
		mana -= ability.mana_cost
	_start_cast(ability)

func _start_cast(ability: AbilityDefinition) -> void:
	_cast_ability = ability
	if ability.cast_time <= 0.0:
		_finish_cast()
		return
	_cast_timer = ability.cast_time
	_spawn_cast_telegraph(ability)
	DebugManager.register_combat_event("cast", {
		"ability": ability.id,
		"phase": &"start",
		"cast_time": ability.cast_time,
		"mana_cost": ability.mana_cost,
	})
	EventBus.ability_cast_started.emit(ability)
	cast_started.emit(ability)

func _finish_cast() -> void:
	var ability := _cast_ability
	_cast_ability = null
	_cast_timer = 0.0
	_free_cast_telegraph()
	if ability == null:
		return
	var targets: Array = _resolve_targets(ability)
	var targets_hit := 0
	for target: Object in targets:
		var result := DamageSystem.apply(DamageEvent.create(target, ability.damage, self))
		if result.valid:
			targets_hit += 1
			_spawn_impact_burst(ability, target)
	DebugManager.register_combat_event("cast", {
		"ability": ability.id,
		"phase": &"complete",
		"targets_hit": targets_hit,
	})
	EventBus.ability_cast_completed.emit(ability, targets_hit)
	cast_completed.emit(ability, targets_hit)

func _resolve_targets(ability: AbilityDefinition) -> Array:
	match ability.area_mode:
		AbilityDefinition.AreaMode.CENTERED:
			return TargetQuery.enemies_in_blast(self, ability.range, ability.width, ability.max_targets, self)
		_:
			return TargetQuery.enemies_in_area(self, facing, ability.range, ability.width, ability.max_targets, self)

func _spawn_cast_telegraph(ability: AbilityDefinition) -> void:
	if ability.cast_effect == null:
		return
	var telegraph: Node2D = ability.cast_effect.instantiate()
	telegraph.add_to_group("effects")
	add_child(telegraph)
	telegraph.scale = Vector2(ability.range / CastTelegraph.BASE_SIZE.x, ability.width / CastTelegraph.BASE_SIZE.y)
	if ability.area_mode == AbilityDefinition.AreaMode.CENTERED:
		telegraph.position = Vector2.ZERO
	else:
		telegraph.position = Vector2(float(facing) * ability.range * 0.5, 0.0)
	_cast_telegraph = telegraph

func _free_cast_telegraph() -> void:
	if _cast_telegraph != null:
		_cast_telegraph.queue_free()
		_cast_telegraph = null

func _spawn_impact_burst(ability: AbilityDefinition, target: Object) -> void:
	if ability.impact_effect == null:
		return
	var burst: Node2D = ability.impact_effect.instantiate()
	burst.add_to_group("effects")
	var world := get_parent()
	if world == null:
		burst.queue_free()
		return
	world.add_child(burst)
	burst.global_position = (target as Node2D).global_position

func _tick_attack(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _attack_active > 0.0:
		_attack_active = maxf(0.0, _attack_active - delta)
		if _attack_active == 0.0:
			_end_basic_attack()
	if Input.is_action_just_pressed("attack") and _attack_timer <= 0.0 and _attack_active <= 0.0:
		_start_basic_attack()

func _start_basic_attack() -> void:
	_attack_timer = basic_attack_cooldown
	_attack_active = basic_attack_duration
	_attack_hit_targets.clear()
	if _attack_hitbox == null:
		return
	var hit_size: Vector2 = (_attack_hitbox.get_node("Collision").shape as RectangleShape2D).size
	_attack_hitbox.position = Vector2(float(facing) * basic_attack_range * 0.5, 0.0)
	_attack_hitbox.scale = Vector2(basic_attack_range / hit_size.x, 1.0)
	_attack_hitbox.monitoring = true
	for body: Node in _attack_hitbox.get_overlapping_bodies():
		_attack_hit(body)
	if not _attack_hitbox.body_entered.is_connected(_attack_hit):
		_attack_hitbox.body_entered.connect(_attack_hit)
	attack_started.emit()

func _end_basic_attack() -> void:
	if _attack_hitbox != null:
		_attack_hitbox.monitoring = false

func _attack_hit(body: Node) -> void:
	if not body is Mob:
		return
	if _attack_hit_targets.has(body):
		return
	_attack_hit_targets.append(body)
	(body as Mob).take_damage(basic_attack_damage, self)

static func _state_name(state_value: int) -> StringName:
	match state_value:
		State.RUN:
			return &"run"
		State.JUMP:
			return &"jump"
		State.FALL:
			return &"fall"
	return &"idle"

func _update_timers(delta: float) -> void:
	_coyote = coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

func _update_facing() -> void:
	if move_direction == 0.0:
		return
	facing = signi(move_direction)
	if _visual != null:
		_visual.scale.x = float(facing)

func _apply_horizontal(delta: float) -> void:
	var target := move_direction * run_speed
	var rate := ground_deceleration
	if move_direction != 0.0:
		rate = ground_acceleration if is_on_floor() else air_acceleration
	elif is_on_floor():
		rate = ground_deceleration
	else:
		rate = air_deceleration
	velocity.x = move_toward(velocity.x, target, rate * delta)

func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
		return
	var gravity_scale := 1.0
	if velocity.y < 0.0:
		gravity_scale = rise_gravity_multiplier if Input.is_action_pressed("jump") else jump_cut_multiplier
	elif velocity.y > 0.0:
		gravity_scale = fall_gravity_multiplier
	velocity.y += gravity * gravity_scale * delta

func _apply_jump() -> void:
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0

func _update_state() -> void:
	var new_state: State
	if is_on_floor():
		new_state = State.RUN if absf(velocity.x) > 1.0 else State.IDLE
	elif velocity.y < 0.0:
		new_state = State.JUMP
	else:
		new_state = State.FALL
	state = new_state
