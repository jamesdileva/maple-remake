extends Node

signal lesson_triggered(lesson: LessonDefinition)

const LESSONS_DIR := "res://data/tutorial/"

var is_playing := false

var _lessons: Array[LessonDefinition] = []
var _seen := {}
var _active: LessonDefinition = null
var _active_progress := 0.0
var _listening := false

func _ready() -> void:
	_load_lessons()
	_listen(true)

func _exit_tree() -> void:
	_listen(false)

func reset() -> void:
	_seen.clear()
	for lesson: LessonDefinition in _lessons:
		_seen[lesson.id] = false
	_active = null
	_active_progress = 0.0
	is_playing = false

func play() -> void:
	is_playing = true

func _listen(enabled: bool) -> void:
	if enabled and not _listening:
		EventBus.ability_cast_completed.connect(_on_cast_completed)
		EventBus.mob_died.connect(_on_mob_died)
		_listening = true
	elif not enabled and _listening:
		if EventBus.ability_cast_completed.is_connected(_on_cast_completed):
			EventBus.ability_cast_completed.disconnect(_on_cast_completed)
		if EventBus.mob_died.is_connected(_on_mob_died):
			EventBus.mob_died.disconnect(_on_mob_died)
		_listening = false

func _load_lessons() -> void:
	var directory := DirAccess.open(LESSONS_DIR)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var lesson := load(LESSONS_DIR + file_name) as LessonDefinition
		if lesson != null:
			_lessons.append(lesson)
	_lessons.sort_custom(func(a: LessonDefinition, b: LessonDefinition) -> bool:
		return String(a.id) < String(b.id))
	for lesson: LessonDefinition in _lessons:
		_seen[lesson.id] = false

func lesson_index(lesson_id: StringName) -> int:
	for index in range(_lessons.size()):
		if _lessons[index].id == lesson_id:
			return index
	return -1

func lesson_count() -> int:
	return _lessons.size()

func all_lessons() -> Array[LessonDefinition]:
	return _lessons.duplicate()

func is_seen(lesson_id: StringName) -> bool:
	return _seen.has(lesson_id) and bool(_seen[lesson_id])

func seen_count() -> int:
	var seen := 0
	for lesson_id: StringName in _seen:
		if _seen[lesson_id]:
			seen += 1
	return seen

func active_lesson() -> LessonDefinition:
	return _active

func active_progress() -> float:
	return _active_progress

func _pick_next() -> LessonDefinition:
	for lesson: LessonDefinition in _lessons:
		if lesson.show_once and is_seen(lesson.id):
			continue
		if _dependencies_met(lesson):
			return lesson
	return null

func _dependencies_met(lesson: LessonDefinition) -> bool:
	for dependency: StringName in lesson.depends_on:
		if not is_seen(dependency):
			return false
	return true

func _physics_process(delta: float) -> void:
	if not is_playing or _lessons.is_empty():
		return
	if _active == null:
		_active = _pick_next()
		_active_progress = 0.0
		return
	_tick_active(delta)

func _tick_active(delta: float) -> void:
	var lesson := _active
	if lesson == null:
		return
	match lesson.bind:
		LessonDefinition.Bind.TIMER:
			_active_progress += delta / maxf(0.1, lesson.threshold)
		LessonDefinition.Bind.PLAYER:
			if _is_pressed(lesson.key_action):
				_active_progress += delta / maxf(0.1, lesson.threshold)
		LessonDefinition.Bind.ATTACK:
			if Input.is_action_just_pressed("attack"):
				_complete(lesson)
				return
		LessonDefinition.Bind.ADVANCED:
			var upgraded := _player()
			if upgraded != null and upgraded.advanced:
				_complete(lesson)
				return
	if _active_progress >= 1.0:
		_complete(lesson)

func _complete(lesson: LessonDefinition) -> void:
	if lesson == null:
		return
	_seen[lesson.id] = true
	lesson_triggered.emit(lesson)
	DebugManager.register_combat_event("lesson_seen", {"lesson": lesson.id})
	_active = null
	_active_progress = 0.0

func complete_external(lesson_id: StringName) -> bool:
	if not is_playing:
		return false
	var index := lesson_index(lesson_id)
	if index < 0 or is_seen(lesson_id):
		return false
	_complete(_lessons[index])
	return true

func _on_cast_completed(ability: AbilityDefinition, _targets_hit: int) -> void:
	if not is_playing:
		return
	if ability != null and ability.area_mode == AbilityDefinition.AreaMode.CENTERED:
		complete_external(&"5_fma")
	if _active != null and _active.bind == LessonDefinition.Bind.SKILL_CAST:
		_complete(_active)

func _on_mob_died(_mob_id: StringName, _xp: float, definition: Resource) -> void:
	if not is_playing:
		return
	if definition is MobDefinition and (definition as MobDefinition).chain != null:
		complete_external(&"8_chains")

func _is_pressed(action: StringName) -> bool:
	if action.is_empty() or not InputMap.has_action(String(action)):
		return false
	return Input.is_action_pressed(String(action))

func _player() -> Player:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as Player
