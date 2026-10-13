class_name CombatLab
extends Node

const LEVELS := [1, 5, 10, 20, 30, 40, 50]
const COUNTS := [1, 10, 50, 100, 250]
const MOB_PATHS := [
	"res://data/mobs/test_slime.tres",
	"res://data/mobs/lesser_slime.tres",
	"res://data/mobs/bomb_slime.tres",
]
const GEAR_PATHS := [
	"res://data/equipment/rusty_blade.tres",
	"res://data/equipment/iron_sword.tres",
	"res://data/equipment/cloth_cap.tres",
	"res://data/equipment/cloth_tunic.tres",
	"res://data/equipment/traveler_pants.tres",
]
const CLASS_PATHS := [
	"res://data/classes/mage.tres",
	"res://data/classes/warrior.tres",
	"res://data/classes/archer.tres",
	"res://data/classes/assassin.tres",
]

@onready var _class_option: OptionButton = %ClassOption
@onready var _level_option: OptionButton = %LevelOption
@onready var _gear_option: OptionButton = %GearOption
@onready var _mob_option: OptionButton = %MobOption
@onready var _count_option: OptionButton = %CountOption
@onready var _boss_option: OptionButton = %BossOption
@onready var _readout: Label = %Readout

var _lab_mobs: Array = []
var _refresh_accum := 0.0
var meter := DamageMeter.new()

func _ready() -> void:
	_populate_options()
	EventBus.damage_applied.connect(meter.record_damage)
	EventBus.mob_died.connect(meter.record_kill)
	EventBus.ability_cast_completed.connect(meter.record_cast)
	_class_option.item_selected.connect(_on_class_selected)
	_level_option.item_selected.connect(_on_level_selected)
	_gear_option.item_selected.connect(_on_gear_selected)
	%SpawnButton.pressed.connect(spawn)
	%KillButton.pressed.connect(kill)
	%ResetButton.pressed.connect(reset_encounter)
	%ManaButton.pressed.connect(_on_mana_pressed)
	%GodButton.pressed.connect(_on_god_pressed)
	_class_option.grab_focus()
	_refresh()

func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= 0.25:
		_refresh_accum = 0.0
		_refresh()

func set_class(character_class: ClassDefinition) -> bool:
	var player := _player()
	if player == null or character_class == null:
		return false
	player.apply_class(character_class)
	_refresh()
	return true

func set_level(level_value: int) -> bool:
	var player := _player()
	if player == null:
		return false
	player.set_level(level_value)
	_refresh()
	return true

func set_gear(gear_path: String) -> bool:
	var player := _player()
	if player == null:
		return false
	if gear_path.is_empty():
		for slot_name in [&"weapon", &"top", &"bottom", &"helmet"]:
			player.unequip(slot_name)
		_refresh()
		return true
	var gear: EquipmentDefinition = load(gear_path)
	if gear == null:
		return false
	player.equip(gear)
	_refresh()
	return true

func set_mob(mob_path: String) -> bool:
	var definition: MobDefinition = load(mob_path) if not mob_path.is_empty() else null
	if definition == null:
		return false
	_mob_option.select(_mob_index(mob_path))
	_refresh()
	return true

func spawn_count() -> int:
	return COUNTS[_count_option.selected]

func spawn() -> int:
	var mob_path: String = MOB_PATHS[_mob_option.selected]
	var definition: MobDefinition = load(mob_path)
	if definition == null or definition.mob_scene == null:
		return 0
	var player := _player()
	var origin := Vector2.ZERO
	if player != null:
		origin = player.global_position
	var count: int = COUNTS[_count_option.selected]
	var spawned := 0
	for index in range(count):
		var offset := 0.0
		if count > 1:
			offset = -230.0 + float(index) * (460.0 / float(count - 1))
		var mob: Mob = definition.mob_scene.instantiate()
		mob.definition = definition
		get_parent().add_child(mob)
		mob.global_position = origin + Vector2(offset, 16.0)
		_lab_mobs.append(mob)
		spawned += 1
	DebugManager.register_combat_event("lab_spawn", {"mob": definition.id, "count": spawned})
	_refresh()
	return spawned

func kill() -> int:
	var killed := DebugManager.kill_all_enemies()
	_refresh()
	return killed

func reset_encounter() -> void:
	for mob in _lab_mobs:
		if is_instance_valid(mob) and not mob.is_queued_for_deletion():
			mob.queue_free()
	_lab_mobs.clear()
	var player := _player()
	if player != null:
		player.hp = player.max_hp
		player.mana = player.max_mana
	meter.reset()
	DebugManager.reset_counters()
	_refresh()

func lab_mob_count() -> int:
	var count := 0
	for mob in _lab_mobs:
		if is_instance_valid(mob) and not mob.is_queued_for_deletion():
			count += 1
	return count

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func _populate_options() -> void:
	_class_option.clear()
	for path in CLASS_PATHS:
		var character_class: ClassDefinition = load(path)
		_class_option.add_item(character_class.display_name if character_class != null else path)
	_level_option.clear()
	for level_value in LEVELS:
		_level_option.add_item(str(level_value))
	_gear_option.clear()
	_gear_option.add_item("None")
	for path in GEAR_PATHS:
		var gear: EquipmentDefinition = load(path)
		_gear_option.add_item(gear.display_name if gear != null else path)
	_mob_option.clear()
	for path in MOB_PATHS:
		var definition: MobDefinition = load(path)
		_mob_option.add_item(definition.display_name if definition != null else path)
	_count_option.clear()
	for count in COUNTS:
		_count_option.add_item(str(count))
	_boss_option.clear()
	_boss_option.add_item("No boss yet")
	_boss_option.disabled = true

func _mob_index(mob_path: String) -> int:
	var index := MOB_PATHS.find(mob_path)
	return index if index >= 0 else 0

func _on_class_selected(index: int) -> void:
	var character_class: ClassDefinition = load(CLASS_PATHS[index])
	set_class(character_class)

func _on_level_selected(index: int) -> void:
	set_level(LEVELS[index])

func _on_gear_selected(index: int) -> void:
	if index == 0:
		set_gear("")
	else:
		set_gear(GEAR_PATHS[index - 1])

func _on_mana_pressed() -> void:
	DebugManager.toggle_infinite_mana()
	_refresh()

func _on_god_pressed() -> void:
	DebugManager.toggle_god_mode()
	_refresh()

func _refresh() -> void:
	if _readout == null:
		return
	var player := _player()
	var player_text := "no player"
	if player != null:
		var gear_text := "none"
		var weapon: EquipmentDefinition = player.equipped_in(&"weapon")
		if weapon != null:
			gear_text = weapon.display_name
		var class_text := "Adventurer"
		if player.class_definition != null:
			class_text = player.class_definition.display_name
		player_text = "%s lv %d | %s | HP %.0f MP %.0f" % [
			class_text, player.level, gear_text, player.hp, player.mana,
		]
	var definition: MobDefinition = load(MOB_PATHS[_mob_option.selected])
	_readout.text = "%s | %s x %d | alive %d | dmg %.0f dps %.0f crit %d kills %d | mana %s | god %s" % [
		player_text,
		definition.display_name if definition != null else "?",
		COUNTS[_count_option.selected],
		lab_mob_count(),
		meter.total_damage,
		meter.dps(),
		meter.crits,
		meter.kills,
		"ON" if DebugManager.infinite_mana else "off",
		"ON" if DebugManager.god_mode else "off",
	]
	(%ManaButton as Button).text = "Mana: %s" % ("ON" if DebugManager.infinite_mana else "off")
	(%GodButton as Button).text = "God: %s" % ("ON" if DebugManager.god_mode else "off")
