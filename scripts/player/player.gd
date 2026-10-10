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
var _visual: Node2D

func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node2D
	add_to_group("player")

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	move_direction = Input.get_axis("move_left", "move_right")
	_update_facing()
	_apply_horizontal(delta)
	_apply_gravity(delta)
	_apply_jump()
	move_and_slide()
	_update_state()

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
