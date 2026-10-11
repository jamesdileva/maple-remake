class_name LevelHud
extends CanvasLayer

@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_label: Label = %XpLabel

var _player: Player

func _ready() -> void:
	var parent := get_parent()
	if parent is Player:
		bind(parent as Player)

func bind(player: Player) -> void:
	if _player != null:
		if _player.xp_gained.is_connected(_on_xp_gained):
			_player.xp_gained.disconnect(_on_xp_gained)
		if _player.leveled_up.is_connected(_refresh):
			_player.leveled_up.disconnect(_refresh)
	_player = player
	if _player == null:
		return
	_player.xp_gained.connect(_on_xp_gained)
	_player.leveled_up.connect(_refresh)
	_refresh()

func _on_xp_gained(_amount: float) -> void:
	_refresh()

func _refresh() -> void:
	if _player == null:
		return
	_level_label.text = "Lv %d" % _player.level
	var table := _player.xp_table
	if table == null:
		_xp_bar.value = 0.0
		_xp_label.text = ""
		return
	_xp_bar.max_value = 100.0
	_xp_bar.value = _player.level_progress() * 100.0
	if table.is_max_level(_player.level):
		_xp_label.text = "MAX"
	else:
		_xp_label.text = "%.0f / %.0f" % [_player.xp_into_level(), _player.xp_to_next_level()]
