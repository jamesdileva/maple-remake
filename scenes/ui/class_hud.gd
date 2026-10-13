class_name ClassHud
extends CanvasLayer

@onready var _class_label: Label = %ClassName
@onready var _level_label: Label = %ClassLevel
@onready var _ability_label: Label = %Abilities
@onready var _shield_label: Label = %ShieldLabel
@onready var _summon_label: Label = %Summonlabel

var _player: Player

func _ready() -> void:
	var parent := get_parent()
	if parent is Player:
		bind(parent as Player)

func bind(player: Player) -> void:
	if _player != null:
		if _player.shield_applied.is_connected(_on_shield_changed):
			_player.shield_applied.disconnect(_on_shield_changed)
		if _player.shield_broken.is_connected(_on_summon_changed):
			_player.shield_broken.disconnect(_on_summon_changed)
		if _player.summon_spawned.is_connected(_on_summon_changed):
			_player.summon_spawned.disconnect(_on_summon_changed)
		if _player.weapon_swapped.is_connected(_on_summon_changed):
			_player.weapon_swapped.disconnect(_on_summon_changed)
	_player = player
	if _player == null:
		return
	_player.shield_applied.connect(_on_shield_changed)
	_player.shield_broken.connect(_on_summon_changed)
	_player.summon_spawned.connect(_on_summon_changed)
	_player.weapon_swapped.connect(_on_summon_changed)
	_refresh()

func _on_shield_changed(_amount: float) -> void:
	_refresh()

func _on_summon_changed(_summon_or_nothing) -> void:
	_refresh()

func _refresh() -> void:
	if _player == null:
		return
	var character_class := _player.class_definition
	_class_label.text = character_class.display_name if character_class != null else "Adventurer"
	_level_label.text = "Lv %d" % _player.level
	if character_class == null:
		_ability_label.text = ""
		_shield_label.text = ""
		_summon_label.text = ""
		return
	var lines: Array = []
	for index in range(6):
		var ability: AbilityDefinition = _player.ability_at(index)
		if ability == null:
			continue
		lines.append("%d %s" % [index + 1, ability.display_name])
	_ability_label.text = "\n".join(lines)
	if _player.advanced:
		_class_label.text = "%s (Advanced)" % _class_label.text
	if _player.wield_alternate:
		_class_label.text = "%s [Crossbow]" % _class_label.text
	_shield_label.text = "shield %d" % int(_player.shield_hp()) if _player.is_shielded() else ""
	_summon_label.text = "summons %d" % _player.active_summons() if _player.active_summons() > 0 else ""
