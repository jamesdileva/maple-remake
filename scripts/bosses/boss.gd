class_name Boss
extends Mob

signal phase_changed(phase_index: int)
signal attack_started(attack_id: StringName)
signal attack_resolved(attack_id: StringName, hits: int)

enum State { IDLE, WINDUP, ACTIVE, RECOVER }

const TELEGRAPH_SCENE_PATH := "res://scenes/effects/cast_telegraph.tscn"
const IMPACT_SCENE_PATH := "res://scenes/effects/impact_burst.tscn"

var phase_index := 0
var state: State = State.IDLE

var _attack_index := 0
var _state_timer := 0.0
var _facing := 1
var _telegraph: Node2D
var _spawn_position := Vector2.ZERO
var _boss_definition: BossDefinition

func _ready() -> void:
	super._ready()
	_spawn_position = global_position
	_boss_definition = definition as BossDefinition
	if _boss_definition != null:
		scale = Vector2.ONE * maxf(0.1, _boss_definition.display_scale)
		if _visual != null:
			_visual.modulate = _boss_definition.tint
	EventBus.player_died.connect(_on_player_died)

func _exit_tree() -> void:
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
	_free_telegraph()

func state_name() -> StringName:
	match state:
		State.WINDUP:
			return &"windup"
		State.ACTIVE:
			return &"active"
		State.RECOVER:
			return &"recover"
	return &"idle"

func current_attack() -> BossAttackDefinition:
	var attacks := _phase_attacks()
	if attacks.is_empty():
		return null
	return attacks[_attack_index % attacks.size()]

func take_damage(amount: float, source: Node = null) -> float:
	var dealt := super.take_damage(amount, source)
	if not dead:
		_update_phase()
	return dealt

func reset() -> void:
	if dead:
		return
	_free_telegraph()
	if definition != null:
		hp = definition.max_hp
	if phase_index != 0:
		phase_index = 0
		phase_changed.emit(phase_index)
	_attack_index = 0
	state = State.IDLE
	_state_timer = 0.2
	_facing = 1
	velocity = Vector2.ZERO
	global_position = _spawn_position
	DebugManager.register_combat_event("boss_reset", {"hp": hp})

func _physics_process(delta: float) -> void:
	if dead:
		return
	velocity.y += _gravity * delta
	if DebugManager.disable_ai or _boss_definition == null:
		velocity.x = 0.0
		move_and_slide()
		_animate_visual(delta)
		return
	match state:
		State.IDLE:
			_track_player()
			velocity.x = float(_facing) * _move_speed
			_state_timer = maxf(0.0, _state_timer - delta)
			if _state_timer <= 0.0:
				_begin_windup()
		State.WINDUP:
			velocity.x = 0.0
			_state_timer = maxf(0.0, _state_timer - delta)
			if _state_timer <= 0.0:
				_execute_attack()
		State.ACTIVE:
			velocity.x = 0.0
			_state_timer = maxf(0.0, _state_timer - delta)
			if _state_timer <= 0.0:
				_begin_recover()
		State.RECOVER:
			velocity.x = 0.0
			_state_timer = maxf(0.0, _state_timer - delta)
			if _state_timer <= 0.0:
				_begin_idle()
	move_and_slide()
	_animate_visual(delta)

func _phase_attacks() -> Array:
	if _boss_definition == null or _boss_definition.phases.is_empty():
		return []
	if phase_index < 0 or phase_index >= _boss_definition.phases.size():
		return []
	return _boss_definition.phases[phase_index].attacks

func _update_phase() -> void:
	if _boss_definition == null or _boss_definition.phases.is_empty():
		return
	var fraction := 0.0
	if definition != null and definition.max_hp > 0.0:
		fraction = clampf(hp / definition.max_hp, 0.0, 1.0)
	var matched := 0
	for index in range(_boss_definition.phases.size()):
		if fraction <= _boss_definition.phases[index].threshold:
			matched = index
	if matched == phase_index:
		return
	phase_index = matched
	_attack_index = 0
	_free_telegraph()
	state = State.IDLE
	_state_timer = 0.2
	phase_changed.emit(phase_index)
	DebugManager.register_combat_event("boss_phase", {"phase": phase_index})

func _track_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	_facing = 1 if player.global_position.x >= global_position.x else -1
	if _visual != null:
		_visual.scale.x = float(_facing)

func _begin_idle() -> void:
	state = State.IDLE
	var next := current_attack()
	_state_timer = next.cooldown if next != null else 0.4

func _begin_windup() -> void:
	var attack := current_attack()
	if attack == null:
		_state_timer = 0.4
		return
	_track_player()
	state = State.WINDUP
	_state_timer = attack.windup_time
	_spawn_telegraph(attack)
	attack_started.emit(attack.id)
	DebugManager.register_combat_event("boss_telegraph", {"attack": attack.id})

func _execute_attack() -> void:
	var attack := current_attack()
	_free_telegraph()
	if attack == null:
		_begin_recover()
		return
	state = State.ACTIVE
	_state_timer = attack.active_time
	var hits := _strike(attack)
	_spawn_impact(attack)
	attack_resolved.emit(attack.id, hits)
	DebugManager.register_combat_event("boss_attack", {"attack": attack.id, "hits": hits})

func _begin_recover() -> void:
	var attack := current_attack()
	state = State.RECOVER
	_state_timer = attack.recover_time if attack != null else 0.3
	_attack_index += 1

func _attack_center(attack: BossAttackDefinition) -> Vector2:
	if attack.area_mode == BossAttackDefinition.Area.CENTERED:
		return global_position
	return global_position + Vector2(float(_facing) * attack.range * 0.5, 0.0)

func _spawn_telegraph(attack: BossAttackDefinition) -> void:
	_free_telegraph()
	var packed: PackedScene = load(TELEGRAPH_SCENE_PATH)
	if packed == null:
		return
	var telegraph := packed.instantiate() as CastTelegraph
	if telegraph == null:
		return
	var world := get_parent()
	if world == null:
		telegraph.queue_free()
		return
	world.add_child(telegraph)
	var telegraph_scale := Vector2(attack.range / CastTelegraph.BASE_SIZE.x, attack.width / CastTelegraph.BASE_SIZE.y)
	telegraph.scale = telegraph_scale
	telegraph.base_scale = telegraph_scale
	telegraph.modulate = attack.telegraph_color
	telegraph.global_position = _attack_center(attack)
	_telegraph = telegraph
	telegraph.add_to_group("effects")

func _free_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null

func _strike(attack: BossAttackDefinition) -> int:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not is_instance_valid(player):
		return 0
	var center := _attack_center(attack)
	var target := player.global_position
	if absf(target.x - center.x) > attack.range * 0.5:
		return 0
	if absf(target.y - center.y) > attack.width * 0.5:
		return 0
	player.take_damage(attack.damage, self)
	return 1

func _spawn_impact(attack: BossAttackDefinition) -> void:
	var packed: PackedScene = load(IMPACT_SCENE_PATH)
	if packed == null:
		return
	var burst := packed.instantiate() as Node2D
	if burst == null:
		return
	burst.add_to_group("effects")
	var world := get_parent()
	if world == null:
		burst.queue_free()
		return
	world.add_child(burst)
	burst.global_position = _attack_center(attack)

func _on_player_died() -> void:
	reset()
