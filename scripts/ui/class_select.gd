class_name ClassSelectOverlay
extends CanvasLayer

signal class_chosen(class_id: StringName)

const CLASS_DIR := "res://data/classes/"

var _definitions: Array[ClassDefinition] = []
var _buttons: Array[Button] = []

func _ready() -> void:
	_build()
	visible = true
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func options_container() -> VBoxContainer:
	return get_node_or_null("%Options") as VBoxContainer

func options_count() -> int:
	return _buttons.size()

func choose_class(class_id: StringName) -> bool:
	for definition in _definitions:
		if definition != null and definition.id == class_id:
			_choose(definition)
			return true
	return false

func _build() -> void:
	var container := options_container()
	if container == null:
		return
	_definitions = _load_classes()
	for definition in _definitions:
		var button := Button.new()
		button.name = String(definition.id).capitalize()
		button.custom_minimum_size = Vector2(0.0, 58.0)
		button.text = "%s   |   %d HP / %d MP   |   %d skills" % [
			definition.display_name,
			int(definition.starting_hp),
			int(definition.starting_mana),
			_ability_count(definition),
		]
		button.pressed.connect(_choose.bind(definition))
		container.add_child(button)
		_buttons.append(button)

func _load_classes() -> Array[ClassDefinition]:
	var result: Array[ClassDefinition] = []
	var directory := DirAccess.open(CLASS_DIR)
	if directory == null:
		return result
	var order := {&"mage": 0, &"warrior": 1, &"archer": 2, &"assassin": 3}
	var loaded: Array[ClassDefinition] = []
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var definition := load(CLASS_DIR + file_name) as ClassDefinition
		if definition != null:
			loaded.append(definition)
	loaded.sort_custom(func(a: ClassDefinition, b: ClassDefinition) -> bool:
		return int(order.get(a.id, 99)) < int(order.get(b.id, 99)))
	return loaded

func _ability_count(definition: ClassDefinition) -> int:
	var count := 0
	for ability in definition.ability_slots:
		if ability != null:
			count += 1
	return count

func _choose(definition: ClassDefinition) -> void:
	if definition == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("apply_class"):
		player.apply_class(definition)
	DebugManager.register_combat_event("class_chosen", {"class": definition.id})
	class_chosen.emit(definition.id)
	visible = false
